varying vec3 vNormal;

void main() {
    // reverse normal so it points to camera
    // remap to 0 to +1 space because only color values can be passed through
    vec3 normal = (-vNormal + vec3(1.0)) / vec3(2.0);
	gl_FragColor = vec4(normal, 1.0);
}