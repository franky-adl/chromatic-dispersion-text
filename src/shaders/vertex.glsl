uniform vec3 uDirLight;
varying vec3 vNormal;
varying vec3 vEyeVector;
varying vec3 vDirLight;

void main() {
    // modelMatrix transforms the coordinates local to the model into world space
    vec4 worldPos = modelMatrix * vec4(position, 1.0);
    // viewMatrix transform the world coordinates into the world space viewed by the camera (view space)
    vec4 mvPosition = viewMatrix * worldPos;

    gl_Position = projectionMatrix * mvPosition;

    // normalMatrix transforms the normal vectors local to the model into view space
    vec3 transformedNormal = normalMatrix * normal;
    vNormal = normalize(transformedNormal);
    // vector pointing from camera to the vertex, in view space
    vEyeVector = normalize(mvPosition.xyz);
    // Transform directional light into view space, detailed explanation:
    // This is better illustrated in a diagram, because the directional light vector should point at the same direction on every vertex
    // We first get the point of the virtual sun for every vertex in world space by adding worldPos to uDirLight
    // Then we transform this point into view space, finally we minus it by mvPosition to get the correct light vector on each vertex in view space
    vDirLight = (viewMatrix * vec4(normalize(uDirLight) + worldPos.xyz, 1.0) - mvPosition).xyz;
}