#version 330 core

in vec2 position;

out vec4 color;

uniform int[200] tiles;

// . I O T S Z J L
const vec3 colors[8] = vec3[8](
	vec3(0.1, 0.1, 0.1),
	vec3(0.0, 1.0, 1.0),
	vec3(1.0, 1.0, 0.0),
	vec3(1.0, 0.0, 1.0),
	vec3(0.0, 1.0, 0.0),
	vec3(1.0, 0.0, 0.0),
	vec3(0.0, 0.0, 1.0),
	vec3(1.0, 0.5, 0.0)
);

void main() {
	int x = int(position.x * 5 + 5);
	int y = int(position.y * -10 + 10);
	float xi = (position.x * 5 + 5) - x;
	float yi = (position.y * -10 + 10) - y;
	int i = y * 10 + x;
	int ti = tiles[i];
	vec3 c = colors[ti & 7];
	if ((ti & 8) != 0) {
		if (xi > 0.15 && xi < 0.85 && yi > 0.15 && yi < 0.85) {
			c = colors[0];
		}
	}
	color = vec4(c, 1.0);
}