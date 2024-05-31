#version 120

uniform float rainStrength;
uniform float frameTimeCounter;
//uniform sampler2D noisetex;

attribute vec4 mc_Entity;
attribute vec4 mc_midTexCoord;

varying vec4 color;
varying vec4 texcoord;
varying vec4 lmcoord;
varying vec2 normal;

vec2 normalEncode(vec3 n) {
    vec2 enc = normalize(n.xy) * (sqrt(-n.z*0.5+0.5));
    enc = enc*0.5+0.5;
    return enc;
}

void main()
{
	vec4 position = gl_Vertex;
	float blockId = mc_Entity.x;
	float maxStrength = 1.0 + rainStrength * 0.5;
	if((blockId == 31.0 || blockId == 37.0 || blockId == 38.0) && gl_MultiTexCoord0.t < mc_midTexCoord.t)
	{
		float reset = cos(dot(vec4(frameTimeCounter,position), vec4(1.0,0.05,0.05,0.05)));
		reset = max( reset * reset, max(rainStrength, 0.1));
		position.x += sin(dot(vec4(frameTimeCounter,position), vec4(1.0,0.05,0.05,0.05))) * 0.25 * reset * maxStrength;
		position.z += sin(dot(vec4(frameTimeCounter,position), vec4(1.0,0.05,0.05,0.05))) * 0.25 * reset * maxStrength;
	}
	else if((blockId == 18.0 || blockId == 106.0 || blockId == 161.0 || blockId == 175.0))
	{
		float reset = cos(dot(vec4(frameTimeCounter,position), vec4(1.0,0.05,0.05,0.05)));
		reset = max( reset * reset, max(rainStrength, 0.1));
		position.x += sin(dot(vec4(frameTimeCounter,position), vec4(1.0,0.05,0.05,0.05))) * 0.1 * reset * maxStrength;
		position.z += sin(dot(vec4(frameTimeCounter,position), vec4(1.0,0.05,0.05,0.05))) * 0.1 * reset * maxStrength;
	}
	position = gl_ModelViewMatrix * position;
	gl_Position = gl_ProjectionMatrix * position;
	gl_FogFragCoord = length(position.xyz);
	color = gl_Color;
	texcoord = gl_TextureMatrix[0] * gl_MultiTexCoord0;
	lmcoord = gl_TextureMatrix[1] * gl_MultiTexCoord1;
	normal = normalEncode(gl_NormalMatrix * gl_Normal);
}