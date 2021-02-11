module shaders;

import core.stdc.stdlib : malloc, exit;

import derelict.opengl3.gl3;

import std.conv;
import std.format;
import std.stdio;
import std.string;

struct Shader(string VERT, string FRAG) {
	Uniforms!([VERT, FRAG]) uniforms;
	GLuint id;

	alias id this;

	void initialize() {
		id = compileShaders(VERT, FRAG);
		uniforms.initialize(id);
	}
}

struct Uniforms(string[] SHADERS) {
	mixin template Uniform(string LINE) {
		enum parts = LINE.split(' ');
		enum type = parts[1];
		enum name = parts[2].split(';')[0];
		static if (type.endsWith(']')) {
			enum length = type.split('[')[1].split(']')[0].to!int;
			mixin(q{
				GLuint[%s] %s;
			}.format(length, name));
		} else {
			mixin(q{
				GLuint %s;
			}.format(name));
		}
	}

	static foreach (string shader; SHADERS) {
		static foreach (string line; shader.split('\n')) {
			static if (line.startsWith("uniform")) {
				mixin Uniform!line;
			}
		}
	}

	void initialize(GLuint id) {
		static foreach (string shader; SHADERS) {
			static foreach (string line; shader.split('\n')) {
				static if (line.startsWith("uniform")) {
					assign!line(id);
				}
			}
		}
	}
	
	void assign(string LINE)(GLuint id) {
		enum parts = LINE.split(' ');
		enum type = parts[1];
		enum name = parts[2].split(';')[0];
		static if (type.endsWith(']')) {
			enum length = type.split('[')[1].split(']')[0].to!int;
			for (int i = 0; i < length; i++) {
				mixin(q{
					%s[i] = glGetUniformLocation(id, "%%s[%%s]".format("%s", i).toStringz());
				}.format(name, name));
			}
		} else {
			mixin(q{
				%s = glGetUniformLocation(id, "%s".toStringz());
			}.format(name, name));
		}
	}
}

Shader!(import("shaders/vertex.glsl"), import("shaders/fragment.glsl")) shader;
Shader!(import("shaders/vertex.glsl"), import("shaders/sideFragment.glsl")) sideShader;
Shader!(import("shaders/vertex.glsl"), import("shaders/holdFragment.glsl")) holdShader;

public void initMain() {
	shader.initialize();
}

public void initSide() {
	sideShader.initialize();
}

public void initHold() {
	holdShader.initialize();
}

private GLuint compileShaders(immutable string vertexSrc, immutable string fragmentSrc) {
	auto vertexz = toStringz(vertexSrc);
	auto fragmentz = toStringz(fragmentSrc);
	GLuint vertexID = glCreateShader(GL_VERTEX_SHADER);
	GLuint fragmentID = glCreateShader(GL_FRAGMENT_SHADER);
	GLuint programID = glCreateProgram();
	glShaderSource(vertexID, 1, &vertexz, null);
	glCompileShader(vertexID);
	GLint status;
	glGetShaderiv(vertexID, GL_COMPILE_STATUS, &status);
	if (!status) {
		GLint logSize = 0;
		glGetShaderiv(vertexID, GL_INFO_LOG_LENGTH, &logSize);
		auto mem = malloc(logSize);
		glGetShaderInfoLog(vertexID, logSize, &logSize, cast(char*) mem);
		writeln("Vertex shader failed to compile: ");
		write((cast(char*) mem).fromStringz());
		exit(-1);
	}
	glShaderSource(fragmentID, 1, &fragmentz, null);
	glCompileShader(fragmentID);
	glGetShaderiv(fragmentID, GL_COMPILE_STATUS, &status);
	if (!status) {
		GLint logSize = 0;
		glGetShaderiv(fragmentID, GL_INFO_LOG_LENGTH, &logSize);
		auto mem = malloc(logSize);
		glGetShaderInfoLog(fragmentID, logSize, &logSize, cast(char*) mem);
		writeln("Fragment shader failed to compile: ");
		write((cast(char*) mem).fromStringz());
		exit(-1);
	}
	glAttachShader(programID, vertexID);
	glAttachShader(programID, fragmentID);
	glLinkProgram(programID);
	glGetProgramiv(programID, GL_LINK_STATUS, &status);
	if (!status) {
		GLint logSize = 0;
		glGetShaderiv(programID, GL_INFO_LOG_LENGTH, &logSize);
		auto mem = malloc(logSize);
		glGetShaderInfoLog(programID, logSize, &logSize, cast(char*) mem);
		writeln("Failed to link shaders: ");
		write((cast(char*) mem).fromStringz());
		exit(-1);
	}
	glDeleteShader(vertexID);
	glDeleteShader(fragmentID);
	return programID;
}