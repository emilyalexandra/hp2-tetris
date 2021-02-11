#version 330 core

in vec2 position;

out vec4 color;

uniform int held;

uniform bool[7] inputs = bool[7](
	false, false, false, false, false, false, false
);

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

// Bitmasks (2 rows)
const int shapes[8] = int[8](
	0, 240, 102, 78, 108, 198, 142, 46
);

vec4 getShapeColor(int s, int x, int y, float xi, float yi);

void main() {
	int x = int(floor((position.x / 0.9) * 2 + 2));
	int y = int(floor((position.y / 0.8) * -1 + 1));
	float xi = ((position.x / 0.9) * 2 + 2) - x;
	float yi = ((position.y / 0.8) * -1 + 1) - y;

	vec4 c;
	c = vec4(colors[0], 1.0);
	if (y >= 0 && y < 2 && x >= 0 && x < 4) {
		c = getShapeColor(held, x, y + 1, xi, yi);
	}
	if (position.x < -0.95) {
		int i = int((position.y - 1) * -3);
		if (inputs[i + 1]) {
			c = vec4(colors[i + 2], 1.0);
		}
	}
	color = c;
}

vec4 getShapeColor(int s, int x, int y, float xi, float yi) {
	if (s > 2) {
		if (xi < 0.5) {
			x--;
		}
	}
	int i = 2048;
	i >>= x + y * 4;
	if ((shapes[s] & i) != 0) {
		return vec4(colors[s], 1.0);
	}
	return vec4(colors[0], 1.0);
}