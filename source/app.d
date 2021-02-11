import core.sys.windows.windows;

import derelict.opengl3.gl3;
import derelict.sdl2.sdl;

import std.conv;
import std.datetime.stopwatch;
import std.random;
import std.stdio;
import std.string;

import shaders;

const int WIDTH = 400, HEIGHT = 800;
const int SIDE_WIDTH = 176, SIDE_HEIGHT = 336;
const int HOLD_WIDTH = 176, HOLD_HEIGHT = 96;

const int[2][5][2][4] kicks = [
	[
		[[0, 0], [1, 0], [1, -1], [0, 2], [1, 2]],
		[[0, 0], [-1, 0], [-1, -1], [0, 2], [-1, 2]]
	],
	[
		[[0, 0], [1, 0], [1, 1], [0, -2], [1, -2]],
		[[0, 0], [1, 0], [1, 1], [0, -2], [1, -2]]
	],
	[
		[[0, 0], [-1, 0], [-1, -1], [0, 2], [-1, 2]],
		[[0, 0], [1, 0], [1, -1], [0, 2], [1, 2]]
	],
	[
		[[0, 0], [-1, 0], [-1, 1], [0, -2], [-1 -2]],
		[[0, 0], [-1, 0], [-1, 1], [0, -2], [-1, -2]]
	]
];

const int[2][5][2][4] iKicks = [
	[
		[[0, 0], [-1, 0], [2, 0], [-1, -2], [2, 1]],
		[[0, 0], [-2, 0], [1, 0], [-2, 1], [1, -2]]
	],
	[
		[[0, 0], [2, 0], [-1, 0], [2, -1], [-1, 2]],
		[[0, 0], [-1, 0], [2, 0], [-1, -2], [2, 1]]
	],
	[
		[[0, 0], [1, 0], [-2, 0], [1, 2], [-2, -1]],
		[[0, 0], [2, 0], [-1, 0], [2, -1], [-1, 2]]
	],
	[
		[[0, 0], [-2, 0], [1, 0], [-2, 1], [1, -2]],
		[[0, 0], [1, 0], [-2, 0], [1, 2], [-2, 1]]
	]
];

struct Piece {
	bool[4][4] collision;
	int rotation, color, width;

	this(int color, bool[][] col) {
		this.color = color;
		width = cast(int) col.length;
		for (int x = 0; x < width; x++) {
			for (int y = 0; y < width; y++) {
				collision[x][y] = col[y][x]; // Swap so definitions look nice
			}
		}
	}

	void rot(int r) {
		Piece old = this;
		while (r < 0) {
			r += 4;
		}
		while (r > 0) {
			for (int x = 0; x < width; x++) {
				for (int y = 0; y < width; y++) {
					collision[x][y] = old.collision[y][width - x - 1];
				}
			}
			rotation++;
			if (rotation >= 4) {
				rotation -= 4;
			}
			old = this;
			r--;
		}
	}
}

// I O T S Z J L
Piece[] pieces = [
	Piece(1, [
		[false, false, false, false],
		[true, true, true, true],
		[false, false, false, false],
		[false, false, false, false]
	]),
	Piece(2, [
		[true, true],
		[true, true]
	]),
	Piece(3, [
		[false, true, false],
		[true, true, true],
		[false, false, false]
	]),
	Piece(4, [
		[false, true, true],
		[true, true, false],
		[false, false, false]
	]),
	Piece(5, [
		[true, true, false],
		[false, true, true],
		[false, false, false]
	]),
	Piece(6, [
		[true, false, false],
		[true, true, true],
		[false, false, false]
	]),
	Piece(7, [
		[false, false, true],
		[true, true, true],
		[false, false, false]
	])
];

SDL_Window* window, sideWindow, holdWindow;
SDL_GLContext context, sideContext, holdContext;
// GL needs one, doesn't need to have anything in it though
GLuint vao, sideVao, holdVao;

// External inputs
bool[7] inputDown;

int[int] keys;
void function()[7] keyCallbacks = [
	&hardDrop, &softDrop, &moveLeft, &moveRight, &rotClockwise, &rotAntiClockwise, &hold
];
bool[7] isDown;
StopWatch[7] keyRepeats;
bool paused;

int initialDelay = 200, repeatDelay = 50;

int[20][10] tiles;
int held = 0;
bool canHold = true;
Piece[] bag;
Piece currentPiece;
int px, py;
Piece ghostPiece;
int gx, gy;

StopWatch dropTimer;
StopWatch lastMove;
StopWatch lockOverrideTimer;

void main() {
	init();
	scope(exit) deinit();

	HINSTANCE instance = GetModuleHandle(null);
	SetWindowsHookEx(WH_KEYBOARD_LL, &globalKeyProc, instance, 0);

	keys = [
		0x57: 0,
		0x53: 1,
		0x41: 2,
		0x44: 3,
		VK_UP: 4,
		VK_DOWN: 5,
		0x51: 6,
	];

	nextPiece();

	SDL_ShowWindow(window);
	SDL_ShowWindow(sideWindow);
	SDL_ShowWindow(holdWindow);

	dropTimer.start();
	lastMove.start();

	writeln(holdShader.uniforms.inputs);

	while (true) {
		SDL_Event e;
		while (SDL_PollEvent(&e) != 0) {
			if (e.type == SDL_WINDOWEVENT) {
				if (e.window.event == SDL_WINDOWEVENT_CLOSE) return;
				if (e.window.event == SDL_WINDOWEVENT_MOVED) {
					int x, y;
					SDL_GetWindowPosition(window, &x, &y);
					SDL_SetWindowPosition(sideWindow, x + 410, y);
					SDL_SetWindowPosition(holdWindow, x - 186, y);
				}
			}
			if (e.type == SDL_QUIT) return;
		}
		if (!paused) {
			for (int i = 0; i < keyRepeats.length; i++) {
				if (isDown[i] && keyRepeats[i].peek() > msecs(initialDelay)) {
					keyRepeats[i].setTimeElapsed(keyRepeats[i].peek() - msecs(repeatDelay));
					keyCallbacks[i]();
				}
			}
		}
		Duration d = msecs(800);
		if (isDown[1]) {
			d = msecs(50);
		}
		if (dropTimer.peek() > d) {
			if (!drop()) {
				if (lastMove.peek() > msecs(800) || (lockOverrideTimer.running && lockOverrideTimer.peek() > seconds(8))) {
					lockPiece();
					dropTimer.setTimeElapsed(msecs(0));
				}
				if (!lockOverrideTimer.running) {
					lockOverrideTimer.start();
				}
			} else {
				if (isDown[1]) {
					lastMove.reset();
				}
				dropTimer.setTimeElapsed(msecs(0));
			}
		}
		SDL_GL_MakeCurrent(window, context);
		glClearColor(1.0, 0.6, 0.9, 1.0);
		glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
		glUseProgram(shader);
		for (int x = 0; x < 10; x++) {
			for (int y = 0; y < 20; y++) {
				int i = y * 10 + x;
				int r = tiles[x][y];
				if (x >= gx && y >= gy && x < gx + 4 && y < gy + 4) {
					if (ghostPiece.collision[x - gx][y - gy]) {
						r = ghostPiece.color | 8;
					}
				}
				if (x >= px && y >= py && x < px + 4 && y < py + 4) {
					if (currentPiece.collision[x - px][y - py]) {
						r = currentPiece.color;
					}
				}
				glUniform1i(shader.uniforms.tiles[i], r);
			}
		}

		glBindVertexArray(vao);
		glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
		SDL_GL_SwapWindow(window);

		SDL_GL_MakeCurrent(sideWindow, sideContext);
		glClearColor(1.0, 0.6, 0.9, 1.0);
		glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
		glUseProgram(sideShader);
		glUniform1i(sideShader.uniforms.next[0], bag[0].color);
		glUniform1i(sideShader.uniforms.next[1], bag[1].color);
		glUniform1i(sideShader.uniforms.next[2], bag[2].color);
		glBindVertexArray(sideVao);
		glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
		SDL_GL_SwapWindow(sideWindow);

		SDL_GL_MakeCurrent(holdWindow, holdContext);
		glClearColor(1.0, 0.6, 0.9, 1.0);
		glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
		glUseProgram(holdShader);
		glUniform1i(holdShader.uniforms.held, held);
		for (int i = 0; i < inputDown.length; i++) {
			glUniform1i(holdShader.uniforms.inputs[i], inputDown[i] ? GL_TRUE : GL_FALSE);
		}
		glBindVertexArray(holdVao);
		glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
		SDL_GL_SwapWindow(holdWindow);
	}
}

void init() {
	DerelictSDL2.load();
	DerelictGL3.load();

	if (SDL_Init(SDL_INIT_VIDEO) < 0) {
		throw new Exception("Failed to intialize SDL " ~ to!string(SDL_GetError()));
	}
	SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 3);
	SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 2);
	SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_CORE);
	SDL_GL_SetAttribute(SDL_GL_RED_SIZE, 8);
	SDL_GL_SetAttribute(SDL_GL_GREEN_SIZE, 8);
	SDL_GL_SetAttribute(SDL_GL_BLUE_SIZE, 8);
	SDL_GL_SetAttribute(SDL_GL_ALPHA_SIZE, 8);
	SDL_GL_SetAttribute(SDL_GL_DEPTH_SIZE, 24);
	SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1);
    SDL_GL_SetAttribute(SDL_GL_MULTISAMPLEBUFFERS, 1);
    SDL_GL_SetAttribute(SDL_GL_MULTISAMPLESAMPLES, 4);

	window = SDL_CreateWindow("Tetris but much worse", SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, WIDTH, HEIGHT, SDL_WINDOW_OPENGL | SDL_WINDOW_HIDDEN | SDL_WINDOW_ALWAYS_ON_TOP);
	sideWindow = SDL_CreateWindow("Next", SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, SIDE_WIDTH, SIDE_HEIGHT, SDL_WINDOW_OPENGL | SDL_WINDOW_HIDDEN | SDL_WINDOW_ALWAYS_ON_TOP);
	holdWindow = SDL_CreateWindow("Hold", SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, HOLD_WIDTH, HOLD_HEIGHT, SDL_WINDOW_OPENGL | SDL_WINDOW_HIDDEN | SDL_WINDOW_ALWAYS_ON_TOP);
	
	int x, y;
	SDL_GetWindowPosition(window, &x, &y);
	SDL_SetWindowPosition(sideWindow, x + 410, y);
	SDL_SetWindowPosition(holdWindow, x - 186, y);

	context = SDL_GL_CreateContext(window);
	sideContext = SDL_GL_CreateContext(sideWindow);
	holdContext = SDL_GL_CreateContext(holdWindow);
	
	DerelictGL3.reload();
	
	SDL_GL_MakeCurrent(window, context);
	shaders.initMain();
	glGenVertexArrays(1, &vao);
	SDL_GL_MakeCurrent(sideWindow, sideContext);
	shaders.initSide();
	glGenVertexArrays(1, &sideVao);
	SDL_GL_MakeCurrent(holdWindow, holdContext);
	shaders.initHold();
	glGenVertexArrays(1, &holdVao);
}

void deinit() {
	SDL_GL_DeleteContext(context);
	SDL_Quit();
	DerelictSDL2.unload();
	DerelictGL3.unload();
}

extern(Windows) nothrow LRESULT globalKeyProc(int nCode, WPARAM wParam, LPARAM lParam) {
	try {
		PKBDLLHOOKSTRUCT key = cast(PKBDLLHOOKSTRUCT) lParam;
		int code = key.vkCode;
		if (code == VK_ESCAPE && wParam == WM_KEYDOWN && nCode == HC_ACTION) {
			paused = !paused;
			if (paused) {
				dropTimer.stop();
			} else {
				dropTimer.start();
			}
		} else if (code in keys) {
			int k = keys[code];
			if (!paused && wParam == WM_KEYDOWN && nCode == HC_ACTION) {
				isDown[k] = true;
				keyRepeats[k].setTimeElapsed(msecs(0));
				keyRepeats[k].start();
				keyCallbacks[k]();
			} else if (wParam == WM_KEYUP && nCode == HC_ACTION) {
				isDown[k] = false;
				keyRepeats[k].stop();
				keyRepeats[k].setTimeElapsed(msecs(0));
			}
		}
	} catch (Exception e) {
		// lol
	}
	return CallNextHookEx(null, nCode, wParam, lParam);
}

void resetGame() {
	for (int x = 0; x < 10; x++) {
		for (int y = 0; y < 20; y++) {
			tiles[x][y] = 0;
		}
	}
	held = 0;
	canHold = true;
	bag = [];
	nextPiece();
	INPUT[2] ip;
	ip[0].type = INPUT_KEYBOARD;
	ip[0].ki.wVk = VK_F13;
	ip[0].ki.dwFlags = 0;
	ip[1].type = INPUT_KEYBOARD;
	ip[1].ki.wVk = VK_F13;
	ip[1].ki.dwFlags = KEYEVENTF_KEYUP;
	SendInput(2, ip.ptr, INPUT.sizeof);
}

void nextPiece() {
	if (bag.length < 4) {
		bag ~= randomShuffle(pieces.dup);
	}
	currentPiece = bag[0];
	bag = bag[1..$];
	px = 3;
	py = 0;
	if (currentPiece.width == 2) {
		px = 4;
	}
	genGhost();
}

void genGhost() {
	ghostPiece = currentPiece;
	gx = px;
	gy = py;
	while (tryMove(ghostPiece, gx, gy, 0, 1)) {

	}
}

bool drop() {
	return tryMove(currentPiece, px, py, 0, 1);
}

bool tryMove(ref Piece p, ref int px, ref int py, int xo, int yo) {
	int cx = px + xo;
	int cy = py + yo;
	for (int x = 0; x < p.width; x++) {
		for (int y = 0; y < p.width; y++) {
			if (p.collision[x][y]) {
				if (cx + x < 0 || cx + x >= 10 || cy + y >= 20) {
					return false;
				}
				if (cy + y < 0) {
					continue;
				}
				if (tiles[cx + x][cy + y] != 0) {
					return false;
				}
			}
		}
	}
	px += xo;
	py += yo;
	return true;
}

void lockPiece() {
	for (int x = 0; x < currentPiece.width; x++) {
		for (int y = 0; y < currentPiece.width; y++) {
			if (!currentPiece.collision[x][y] || px + x < 0 || px + x >= 10 || py + y < 0 || py + y >= 20) {
				continue;
			}
			tiles[px + x][py + y] = currentPiece.color;
		}
	}
	bool cleared = false;
	outer:
	for (int y = 19; y >= 0; y--) {
		for (int x = 0; x < 10; x++) {
			if (tiles[x][y] == 0) {
				continue outer;
			}
		}
		cleared = true;
		for (int yl = y; yl > 0; yl--) {
			for (int x = 0; x < 10; x++) {
				tiles[x][yl] = tiles[x][yl - 1];
			}
		}
		for (int x = 0; x < 10; x++) {
			tiles[x][0] = 0;
		}
		y++;
	}
	if (cleared) {
		if (currentPiece.color != 1) {
			INPUT ip;
			ip.type = INPUT_KEYBOARD;
			ip.ki.wVk = cast(ushort) (VK_F13 + currentPiece.color);
			if (inputDown[currentPiece.color - 1]) {
				ip.ki.dwFlags = KEYEVENTF_KEYUP;
			}
			inputDown[currentPiece.color - 1] = !inputDown[currentPiece.color - 1];
			SendInput(1, &ip, INPUT.sizeof);
		} else {
			INPUT[2] ip;
			ip[0].type = INPUT_KEYBOARD;
			ip[0].ki.wVk = cast(ushort) (VK_F13 + currentPiece.color);
			ip[1].type = INPUT_KEYBOARD;
			ip[1].ki.wVk = cast(ushort) (VK_F13 + currentPiece.color);
			ip[1].ki.dwFlags = KEYEVENTF_KEYUP;
			SendInput(2, ip.ptr, INPUT.sizeof);
		}
	}
	nextPiece();
	if (lockOverrideTimer.running) {
		lockOverrideTimer.stop();
		lockOverrideTimer.setTimeElapsed(msecs(0));
	}
	canHold = true;
	if (!tryMove(currentPiece, px, py, 0, 0)) {
		resetGame();
	}
}

void hardDrop() {
	while(drop()) {
	}
	lockPiece();
	dropTimer.setTimeElapsed(msecs(0));
}

void softDrop() {
	// lol
}

void moveLeft() {
	if (tryMove(currentPiece, px, py, -1, 0)) {
		genGhost();
		lastMove.reset();
	}
}

void moveRight() {
	if (tryMove(currentPiece, px, py, 1, 0)) {
		genGhost();
		lastMove.reset();
	}
}

void rotClockwise() {
	tryRot(1);
}

void rotAntiClockwise() {
	tryRot(-1);
}

void tryRot(int r) {
	int[2][5] offsets;
	if (currentPiece.color == 1) {
		offsets = iKicks[currentPiece.rotation][r < 0 ? 0 : 1];
	} else {
		offsets = kicks[currentPiece.rotation][r < 0 ? 0 : 1];
	}
	currentPiece.rot(r);
	for (int i = 0; i < 5; i++) {
		if (tryMove(currentPiece, px, py, offsets[i][0], offsets[i][1])) {
			lastMove.reset();
			genGhost();
			return;
		}
	}
	currentPiece.rot(-r);
}

void hold() {
	if (canHold) {
		if (held == 0) {
			held = currentPiece.color;
			nextPiece();
			canHold = false;
		} else {
			int h = currentPiece.color;
			currentPiece = pieces[held - 1];
			held = h;
			px = 3;
			py = 0;
			if (currentPiece.width == 2) {
				px = 4;
			}
			genGhost();
			canHold = false;
		}
	}
}