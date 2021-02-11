#version 330 core

in vec2 position;

out vec4 color;

uniform int[3] next;

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
	int y = int(floor((position.y / 0.95) * -4 + 4));
	float xi = ((position.x / 0.9) * 2 + 2) - x;
	float yi = ((position.y / 0.95) * -4 + 4) - y;

	vec4 c;
	c = vec4(colors[0], 1.0);
	if (y < 0 || x < 0 || x >= 4 || y >= 12) {
		c = vec4(colors[0], 1.0);
	} else if (y < 3) {
		c = getShapeColor(next[0], x, y + 1, xi, yi);
	} else if (y < 6) {
		c = getShapeColor(next[1], x, y - 2, xi, yi);
	} else if (y < 9) {
		c = getShapeColor(next[2], x, y - 5, xi, yi);
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