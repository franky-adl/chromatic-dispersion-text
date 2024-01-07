uniform float uIorR;
uniform float uIorG;
uniform float uIorB;
uniform float uRefractPower;
uniform float uShininess;
uniform float uDiffuseness;
uniform vec2 u_resolution;
uniform float lod;
uniform sampler2D uTexture;
uniform sampler2D backfaceNormalMap;
uniform samplerCube cubemap;

varying vec3 vNormal;
varying vec3 vEyeVector;
varying vec3 vDirLight;

// number of loops on sampling the chromatic dispersion
const int LOOP = 16;

// formula for Phong reflection, reference from: https://en.wikipedia.org/wiki/Phong_reflection_model
float specular(vec3 light, float shininess, float diffuseness, vec3 normal) {
  vec3 lightVector = normalize(light);
  float LdotN = dot(normal, lightVector);
  vec3 reflectionVector = normalize(2.0 * LdotN * normal - lightVector);

  float RdotV = clamp(dot(reflectionVector, -normalize(vEyeVector)), 0.0, 1.0);
  float RdotV_2 = pow(RdotV, 6.0);
  float RdotV_10 = pow(RdotV, 20.0);
  float kSpecular = smoothstep(0.95, 1.0, RdotV_2);
  float kSpecular2 = RdotV_10 * 0.8;
  // float kDiffuse = smoothstep(0.8, 1.0, LdotN) * 0.4;

  // didn't use diffuse, but used a modified specular instead (kSpecular2) for a better effect
  return kSpecular + kSpecular2;
}

// reference from the original post linked in readme
float fresnel(vec3 eyeVector, vec3 vNormal, float power) {
  float fresnelFactor = abs(dot(eyeVector, vNormal));
  float inversefresnelFactor = 1.0 - fresnelFactor;
  
  return pow(inversefresnelFactor, power);
}

void main() {
  float iorRatioRed = 1.0/uIorR;
  float iorRatioGreen = 1.0/uIorG;
  float iorRatioBlue = 1.0/uIorB;

  vec3 color = vec3(0.0);

  vec2 uv = gl_FragCoord.xy / u_resolution.xy;

  vec3 backfaceNormal = texture2D(backfaceNormalMap, uv).rgb;
  // remap back to -1 to +1 space
  backfaceNormal = backfaceNormal * vec3(2.0) - vec3(1.0);
  float a = 0.33;
  // mix front and back face normals so as to see refraction effect from back face as well
  vec3 normal = vNormal * (1.0 - a) - backfaceNormal * a;
  vec3 nEyeVector = normalize(vEyeVector);
  vec3 refractVecR = refract(nEyeVector, normal, iorRatioRed);
  vec3 refractVecG = refract(nEyeVector, normal, iorRatioGreen);
  vec3 refractVecB = refract(nEyeVector, normal, iorRatioBlue);
  
  for ( int i = 0; i < LOOP; i ++ ) {
    float slide = float(i) / float(LOOP) * 0.05;
    color.r += texture2D(uTexture, uv + refractVecR.xy * (uRefractPower + slide)).r;
    color.g += texture2D(uTexture, uv + refractVecG.xy * (uRefractPower + slide*1.5)).g;
    color.b += texture2D(uTexture, uv + refractVecB.xy * (uRefractPower + slide*2.0)).b;
  }
  // Divide by the number of layers to normalize colors (rgb values can be worth up to the value of LOOP)
  color /= float(LOOP);

  // cubemap reflection
  vec3 reflection = reflect(vEyeVector, vNormal);
  vec4 envColor = textureCubeLodEXT(cubemap, reflection, lod);
  vec3 bfreflection = reflect(vEyeVector, backfaceNormal);
  vec4 bfenvColor = textureCubeLodEXT(cubemap, bfreflection, lod);

  // Fresnel
  float f = fresnel(nEyeVector, vNormal, 8.0);
  color.rgb += f * vec3(1.0);

  gl_FragColor = vec4(color, 1.0) + envColor * 0.8 + bfenvColor * 0.1;

  // transform color from linear colorSpace to sRGBColorSpace
  gl_FragColor = linearToOutputTexel( gl_FragColor );
}