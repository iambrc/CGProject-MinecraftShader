#version 120

uniform sampler2D texture;
uniform int worldTime;

varying vec4 texcoord;
varying vec4 lmcoord;

void main() {
	gl_FragData[0] = texture2D(texture, texcoord.st);
	if (worldTime >= 13000 && worldTime <= 23000 && lmcoord.s > 0.1*lmcoord.t)
		gl_FragData[0] = vec4(0);
}