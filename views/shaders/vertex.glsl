#version 330 core

// Mom can we get geometry shaders
// No we have geometry shaders at home
// Geometry shaders at home: 
const vec2 quadVertices[4] = vec2[4](
	vec2(-1.0, -1.0),
	vec2(1.0, -1.0),
	vec2(-1.0, 1.0),
	vec2(1.0, 1.0)
);

out vec2 position;

void main() {
	gl_Position = vec4(quadVertices[gl_VertexID], 0.0, 1.0);
	position = gl_Position.xy;
}