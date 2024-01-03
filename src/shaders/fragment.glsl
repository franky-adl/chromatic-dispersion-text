uniform float uIorR;
uniform float uIorG;
uniform float uIorB;
uniform float uRefractPower;
uniform float uShininess;
uniform float uDiffuseness;
uniform vec2 u_resolution;
uniform sampler2D uTexture;

varying vec3 vNormal;
varying vec3 vEyeVector;
varying vec3 vDirLight;

// number of loops on sampling the chromatic dispersion
const int LOOP = 16;

// formula for Phong reflection, reference from: https://en.wikipedia.org/wiki/Phong_reflection_model
float specular(vec3 light, float shininess, float diffuseness) {
  vec3 normal = vNormal;
  vec3 lightVector = normalize(light);
  float LdotN = dot(normal, lightVector);
  vec3 reflectionVector = normalize(2.0 * LdotN * normal - lightVector);

  float RdotV = clamp(dot(reflectionVector, -vEyeVector), 0.0, 1.0);
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

  vec3 refractVecR = refract(vEyeVector, vNormal, iorRatioRed);
  vec3 refractVecG = refract(vEyeVector, vNormal, iorRatioGreen);
  vec3 refractVecB = refract(vEyeVector, vNormal, iorRatioBlue);
  
  for ( int i = 0; i < LOOP; i ++ ) {
    float slide = float(i) / float(LOOP) * 0.05;
    color.r += texture2D(uTexture, uv + refractVecR.xy * (uRefractPower + slide)).r;
    color.g += texture2D(uTexture, uv + refractVecG.xy * (uRefractPower + slide*1.5)).g;
    color.b += texture2D(uTexture, uv + refractVecB.xy * (uRefractPower + slide*2.0)).b;
  }
  // Divide by the number of layers to normalize colors (rgb values can be worth up to the value of LOOP)
  color /= float(LOOP);

  // Specular and diffuse reflection
  float reflection = specular(vDirLight, uShininess, uDiffuseness);
  color += reflection;

  // Fresnel
  float f = fresnel(vEyeVector, vNormal, 8.0);
  color.rgb += f * vec3(1.0);

  gl_FragColor = vec4(color, 1.0);

  // transform color from linear colorSpace to sRGBColorSpace
  gl_FragColor = linearToOutputTexel( gl_FragColor );
}