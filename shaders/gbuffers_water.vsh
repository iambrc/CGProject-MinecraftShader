#version 120

attribute vec4 mc_Entity;
uniform int worldTime;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;

varying vec4 color;
varying vec4 texcoord;
varying vec4 lmcoord;
varying vec2 normal;
varying float attr;
varying float blockId;

vec2 normalEncode(vec3 n) {
    vec2 enc = normalize(n.xy) * (sqrt(-n.z*0.5+0.5));
    enc = enc*0.5+0.5;
    return enc;
}

vec4 getBump(vec4 positionInViewCoord) {
	vec4 positionInWorldCoord = gbufferModelViewInverse * positionInViewCoord;
	positionInWorldCoord.xyz += cameraPosition;
	positionInWorldCoord.y += sin(float(worldTime*0.3) + positionInWorldCoord.z *2) * 0.05;
	positionInWorldCoord.xyz -= cameraPosition;
	return gbufferModelView * positionInWorldCoord;
}

void main()
{
	vec4 position = gl_ModelViewMatrix * gl_Vertex;
	blockId = mc_Entity.x;
	color = gl_Color;
	gl_Position = gl_ProjectionMatrix * position;
	if (blockId == 8 || blockId == 9)
	{
		color = vec4(0.05,0.2,0.3,0.5);
		gl_Position = gl_ProjectionMatrix * getBump(position);
	}
	if(gl_Normal.y > -0.9 && (blockId == 8 || blockId == 9))
		attr = 1.0 / 255.0;
	else if (blockId == 95)
		attr = 2.0 / 255.0;
	else
		attr = 0.0;
	gl_FogFragCoord = length(position.xyz);
	texcoord = gl_TextureMatrix[0] * gl_MultiTexCoord0;
	lmcoord = gl_TextureMatrix[1] * gl_MultiTexCoord1;
	normal = normalEncode(gl_NormalMatrix * gl_Normal);
}
