#version 120

const int R8 = 0;
const int colortex4Format = R8;
const int colortex5Format = R8;

uniform float near;
uniform float far;
uniform float aspectRatio;
uniform float viewWidth;
uniform float viewHeight;

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferPreviousProjection;

uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform sampler2D gcolor;
uniform sampler2D gnormal;
uniform sampler2D colortex1;
uniform sampler2D colortex4;
uniform sampler2D colortex5;
uniform sampler2D depthtex0;

varying vec4 texcoord; 
varying float sunVisibility;
varying vec2 lf1Pos;
varying vec2 lf2Pos;
varying vec2 lf3Pos;
varying vec2 lf4Pos;

float A = 0.15;
float B = 0.50;
float C = 0.10;
float D = 0.20;
float E = 0.02;
float F = 0.30;
float W = 13.134;

#define MANHATTAN_DISTANCE(DELTA) abs(DELTA.x)+abs(DELTA.y)
 
#define LENS_FLARE(COLOR, UV, LFPOS, LFSIZE, LFCOLOR) { \
                vec2 delta = UV - LFPOS; delta.x *= aspectRatio; \
                if(MANHATTAN_DISTANCE(delta) < LFSIZE * 2.0) { \
                    float d = max(LFSIZE - sqrt(dot(delta, delta)), 0.0); \
                    COLOR += LFCOLOR.rgb * LFCOLOR.a * smoothstep(0.0, LFSIZE, d) * sunVisibility;\
                } }
 
#define LF1SIZE 0.1
#define LF2SIZE 0.15
#define LF3SIZE 0.25
#define LF4SIZE 0.25

#define MOTIONBLUR_THRESHOLD 0.01
#define MOTIONBLUR_MAX 0.21
#define MOTIONBLUR_STRENGTH 0.5
#define MOTIONBLUR_SAMPLE 5
 
const vec4 LF1COLOR = vec4(1.0, 1.0, 1.0, 0.1);
const vec4 LF2COLOR = vec4(0.42, 0.0, 1.0, 0.1);
const vec4 LF3COLOR = vec4(0.0, 1.0, 0.0, 0.1);
const vec4 LF4COLOR = vec4(1.0, 0.0, 0.0, 0.1);

vec3 uncharted2Tonemap(vec3 x) {
	return ((x*(A*x+C*B)+D*E)/(x*(A*x+B)+D*F))-E/F;
}

vec3 bloom(vec3 color, vec2 uv) {
	return color + texture2D(colortex1, uv).rgb;
}

vec3 normalDecode(vec2 enc) {
    vec4 nn = vec4(2.0 * enc - 1.0, 1.0, -1.0);
    float l = dot(nn.xyz,-nn.xyw);
    nn.z = l;
    nn.xy *= sqrt(l);
    return nn.xyz * 2.0 + vec3(0.0, 0.0, -1.0);
}

vec2 getScreenCoordByViewCoord(vec3 viewCoord) {
	vec4 p = vec4(viewCoord, 1.0);
	p = gbufferProjection * p;
	p /= p.w;
	if(p.z < -1 || p.z > 1)
		return vec2(-1.0);
	p = p * 0.5f + 0.5f;
	return p.st;
}

float linearizeDepth(float depth) {
    return (2.0 * near) / (far + near - depth * (far - near));
}

float getLinearDepthOfViewCoord(vec3 viewCoord) {
	vec4 p = vec4(viewCoord, 1.0);
	p = gbufferProjection * p;
	p /= p.w;
	return linearizeDepth(p.z * 0.5 + 0.5);
}

#define BISEARCH(SEARCHPOINT, DIRVEC, SIGN) DIRVEC *= 0.5; \
					SEARCHPOINT+= DIRVEC * SIGN; \
					uv = getScreenCoordByViewCoord(SEARCHPOINT); \
					sampleDepth = linearizeDepth(texture2DLod(depthtex0, uv, 0.0).x); \
					testDepth = getLinearDepthOfViewCoord(SEARCHPOINT); \
					SIGN = sign(sampleDepth - testDepth);

vec3 waterRayTracing(vec3 startPoint, vec3 direction, vec3 color, float jitter, float fresnel) {
	const float stepBase = 0.025;
	vec3 testPoint = startPoint;
	vec3 lastPoint = testPoint;
	direction *= stepBase;
	bool hit = false;
	vec4 hitColor = vec4(0.0);
	for(int i = 0; i < 40; i++)
	{
		testPoint += direction * pow(float(i + 1 + jitter), 1.46);
		vec2 uv = getScreenCoordByViewCoord(testPoint);
		if(uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0)
		{
			hit = true;
			break;
		}
		float sampleDepth = texture2DLod(depthtex0, uv, 0.0).x;
		sampleDepth = linearizeDepth(sampleDepth);
		float testDepth = getLinearDepthOfViewCoord(testPoint);
		if(sampleDepth < testDepth && testDepth - sampleDepth < (1.0 / 2048.0) * (1.0 + testDepth * 200.0 + float(i)))
		{
			vec3 finalPoint = lastPoint;
			float _sign = 1.0;
			direction = testPoint - lastPoint;
			BISEARCH(finalPoint, direction, _sign);
			BISEARCH(finalPoint, direction, _sign);
			BISEARCH(finalPoint, direction, _sign);
			BISEARCH(finalPoint, direction, _sign);
			uv = getScreenCoordByViewCoord(finalPoint);
			hitColor = vec4(texture2DLod(gcolor, uv, 0.0).rgb, 1.0);
			hitColor.a = clamp(1.0 - pow(distance(uv, vec2(0.5))*2.0, 2.0), 0.0, 1.0);
			hit = true;
			break;
		}
		lastPoint = testPoint;
	}
	if(!hit)
	{
		vec2 uv = getScreenCoordByViewCoord(lastPoint);
		float testDepth = getLinearDepthOfViewCoord(lastPoint);
		float sampleDepth = texture2DLod(depthtex0, uv, 0.0).x;
		sampleDepth = linearizeDepth(sampleDepth);
		if(testDepth - sampleDepth < 0.5)
		{
			hitColor = vec4(texture2DLod(gcolor, uv, 0.0).rgb, 1.0);
			hitColor.a = clamp(1.0 - pow(distance(uv, vec2(0.5))*2.0, 2.0), 0.0, 1.0);
		}
	}
	return mix(color, hitColor.rgb, hitColor.a * fresnel);
}

vec3 waterEffect(vec3 color, vec2 uv, vec3 viewPos, float attr) {
	if(attr == 1.0)
	{
		vec3 normal = normalDecode(texture2D(gnormal, texcoord.st).rg);
		vec3 viewRefRay = reflect(normalize(viewPos), normal);
		vec2 uv2 = texcoord.st * vec2(viewWidth, viewHeight);
		float c = (uv2.x + uv2.y) * 0.25;
		float jitter = mod(c, 1.0);
		float fresnel = 0.02 + 0.98 * pow(1.0 - dot(viewRefRay, normal), 5.0);
		color = waterRayTracing(viewPos + normal * (-viewPos.z / far * 0.2 + 0.05), viewRefRay, color, jitter, fresnel);
	}
	return color;
}

vec3 metalRayTracing(vec3 startPoint, vec3 direction, vec3 color, float jitter) {
	const float stepBase = 0.025;
	vec3 testPoint = startPoint;
	vec3 lastPoint = testPoint;
	direction *= stepBase;
	bool hit = false;
	vec4 hitColor = vec4(0.0);
	for(int i = 0; i < 40; i++)
	{
		testPoint += direction * pow(float(i + 1 + jitter), 1.46);
		vec2 uv = getScreenCoordByViewCoord(testPoint);
		if(uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0)
		{
			hit = true;
			break;
		}
		float sampleDepth = texture2DLod(depthtex0, uv, 0.0).x;
		sampleDepth = linearizeDepth(sampleDepth);
		float testDepth = getLinearDepthOfViewCoord(testPoint);
		if(sampleDepth < testDepth && testDepth - sampleDepth < (1.0 / 2048.0) * (1.0 + testDepth * 200.0 + float(i)))
		{
			vec3 finalPoint = lastPoint;
			float _sign = 1.0;
			direction = testPoint - lastPoint;
			BISEARCH(finalPoint, direction, _sign);
			//BISEARCH(finalPoint, direction, _sign);
			//BISEARCH(finalPoint, direction, _sign);
			//BISEARCH(finalPoint, direction, _sign);
			uv = getScreenCoordByViewCoord(finalPoint);
			hitColor = vec4(texture2DLod(gcolor, uv, 0.0).rgb, 1.0);
			//hitColor.a = clamp(1.0 - pow(distance(uv, vec2(0.5))*2.0, 2.0), 0.0, 1.0);
			hit = true;
			break;
		}
		lastPoint = testPoint;
	}
	if(!hit)
	{
		vec2 uv = getScreenCoordByViewCoord(lastPoint);
		float testDepth = getLinearDepthOfViewCoord(lastPoint);
		float sampleDepth = texture2DLod(depthtex0, uv, 0.0).x;
		sampleDepth = linearizeDepth(sampleDepth);
		if(testDepth - sampleDepth < 0.5)
		{
			hitColor = vec4(texture2DLod(gcolor, uv, 0.0).rgb, 1.0);
			//hitColor.a = clamp(1.0 - pow(distance(uv, vec2(0.5))*2.0, 2.0), 0.0, 1.0);
		}
	}
	return mix(color, hitColor.rgb, 0.2);
}

vec3 metalEffect(vec3 color, vec2 uv, vec3 viewPos, float glassmetal) {
	if (glassmetal == 3.0)
	{
		vec3 normal = normalDecode(texture2D(gnormal, texcoord.st).rg);
		vec3 viewRefRay = reflect(normalize(viewPos), normal);
		vec2 uv2 = texcoord.st * vec2(viewWidth, viewHeight);
		float c = (uv2.x + uv2.y) * 0.25;
		float jitter = mod(c, 1.0);
		color = metalRayTracing(viewPos + normal * (-viewPos.z / far * 0.2 + 0.05), viewRefRay, color, jitter);
	}
	return color;
}

vec3 tonemapping(vec3 color) {
	color = pow(color, vec3(1.4));
	color *= 6.0;
	vec3 curr = uncharted2Tonemap(color);
	vec3 whiteScale = 1.0f/uncharted2Tonemap(vec3(W));
	color = curr*whiteScale;
	return color;
}

vec3 rgbToHsl(vec3 rgbColor) {
    rgbColor = clamp(rgbColor, vec3(0.0), vec3(1.0));
    float h, s, l;
    float r = rgbColor.r, g = rgbColor.g, b = rgbColor.b;
    float minval = min(r, min(g, b));
    float maxval = max(r, max(g, b));
    float delta = maxval - minval;
    l = ( maxval + minval ) / 2.0;  
    if (delta == 0.0) 
    {
        h = 0.0;
        s = 0.0;
    }
    else
    {
        if ( l < 0.5 )
            s = delta / ( maxval + minval );
        else 
            s = delta / ( 2.0 - maxval - minval );
             
        float deltaR = (((maxval - r) / 6.0) + (delta / 2.0)) / delta;
        float deltaG = (((maxval - g) / 6.0) + (delta / 2.0)) / delta;
        float deltaB = (((maxval - b) / 6.0) + (delta / 2.0)) / delta;
         
        if(r == maxval)
            h = deltaB - deltaG;
        else if(g == maxval)
            h = ( 1.0 / 3.0 ) + deltaR - deltaB;
        else if(b == maxval)
            h = ( 2.0 / 3.0 ) + deltaG - deltaR;
             
        if ( h < 0.0 )
            h += 1.0;
        if ( h > 1.0 )
            h -= 1.0;
    }
    return vec3(h, s, l);
}

float hueToRgb(float v1, float v2, float vH) {
    if (vH < 0.0)
        vH += 1.0;
    if (vH > 1.0)
        vH -= 1.0;
    if ((6.0 * vH) < 1.0)
        return (v1 + (v2 - v1) * 6.0 * vH);
    if ((2.0 * vH) < 1.0)
        return v2;
    if ((3.0 * vH) < 2.0)
        return (v1 + ( v2 - v1 ) * ( ( 2.0 / 3.0 ) - vH ) * 6.0);
    return v1;
}
 
vec3 hslToRgb(vec3 hslColor) {
    hslColor = clamp(hslColor, vec3(0.0), vec3(1.0));
    float r, g, b;
    float h = hslColor.r, s = hslColor.g, l = hslColor.b;
    if (s == 0.0)
    {
        r = l;
        g = l;
        b = l;
    }
    else
    {
        float v1, v2;
        if (l < 0.5)
            v2 = l * (1.0 + s);
        else
            v2 = (l + s) - (s * l);
     
        v1 = 2.0 * l - v2;
     
        r = hueToRgb(v1, v2, h + (1.0 / 3.0));
        g = hueToRgb(v1, v2, h);
        b = hueToRgb(v1, v2, h - (1.0 / 3.0));
    }
    return vec3(r, g, b);
}

vec3 vibrance(vec3 hslColor, float v) {
    hslColor.g = pow(hslColor.g, v);
    return hslColor;
}

vec3 colorBalance(vec3 rgbColor, vec3 hslColor, vec3 s, vec3 m, vec3 h, bool p) {
    s *= clamp((hslColor.bbb - 0.333) / -0.25 + 0.5, 0.0, 1.0) * 0.7;
    m *= clamp((hslColor.bbb - 0.333) /  0.25 + 0.5, 0.0, 1.0) *
         clamp((hslColor.bbb + 0.333 - 1.0) / -0.25 + 0.5, 0.0, 1.0) * 0.7;
    h *= clamp((hslColor.bbb + 0.333 - 1.0) /  0.25 + 0.5, 0.0, 1.0) * 0.7;
    vec3 newColor = rgbColor;
    newColor += s;
    newColor += m;
    newColor += h;
    newColor = clamp(newColor, vec3(0.0), vec3(1.0));
    if(p)
    {
        vec3 newHslColor = rgbToHsl(newColor);
        newHslColor.b = hslColor.b;
        newColor = hslToRgb(newHslColor);
    }
    return newColor;
}

vec3 vignette(vec3 color) {
    float dist = distance(texcoord.st, vec2(0.5f));
    dist = clamp(dist * 1.7 - 0.65, 0.0, 1.0);
    dist = smoothstep(0.0, 1.0, dist);
    return color.rgb * (1.0 - dist);
}

vec3 lensFlare(vec3 color, vec2 uv) {
    if(sunVisibility <= 0.0)
        return color;
    LENS_FLARE(color, uv, lf1Pos, LF1SIZE, LF1COLOR);
    LENS_FLARE(color, uv, lf2Pos, LF2SIZE, LF2COLOR);
    LENS_FLARE(color, uv, lf3Pos, LF3SIZE, LF3COLOR);
    LENS_FLARE(color, uv, lf4Pos, LF4SIZE, LF4COLOR);
    return color;
}
 
vec3 motionBlur(vec3 color, vec2 uv, vec4 viewPosition) {
    vec4 worldPosition = gbufferModelViewInverse * viewPosition + vec4(cameraPosition, 0.0);
    vec4 prevClipPosition = gbufferPreviousProjection * gbufferPreviousModelView * (worldPosition - vec4(previousCameraPosition, 0.0));
    vec4 prevNdcPosition = prevClipPosition / prevClipPosition.w;
    vec2 prevUv = (prevNdcPosition * 0.5 + 0.5).st;
    vec2 delta = uv - prevUv;
    float dist = length(delta);
    if(dist > MOTIONBLUR_THRESHOLD)
    {
        delta = normalize(delta);
        dist = min(dist, MOTIONBLUR_MAX) - MOTIONBLUR_THRESHOLD;
        dist *= MOTIONBLUR_STRENGTH;
        delta *= dist / float(MOTIONBLUR_SAMPLE);
        int sampleNum = 1;
        for(int i = 0; i < MOTIONBLUR_SAMPLE; i++)
        {
            uv += delta;
            if(uv.s <= 0.0 || uv.s >= 1.0 || uv.t <= 0.0 || uv.t >= 1.0)
                break;
            color += texture2D(colortex1, uv).rgb;
            sampleNum++;
        }
        color /= float(sampleNum);
    }
    return color;
}

void main() {
	vec3 color =  texture2D(gcolor, texcoord.st).rgb;
	vec3 attrs =  texture2D(colortex4, texcoord.st).rgb;
	float depth = texture2D(depthtex0, texcoord.st).r;
	vec4 viewPosition = gbufferProjectionInverse * vec4(texcoord.s * 2.0 - 1.0, texcoord.t * 2.0 - 1.0, 2.0 * depth - 1.0, 1.0f);
	viewPosition /= viewPosition.w;
	float attr = attrs.r * 255.0;

	vec3 glassmetals =  texture2D(colortex5, texcoord.st).rgb;
	float glassmetal = glassmetals.r * 255.0;

	color = bloom(color, texcoord.st);
	color = waterEffect(color, texcoord.st, viewPosition.xyz, attr);
	color = metalEffect(color, texcoord.st, viewPosition.xyz, glassmetal);
	color = tonemapping(color);

	vec3 hslColor = rgbToHsl(color);
	hslColor = vibrance(hslColor, 0.75);
	color = hslToRgb(hslColor);
	//color = colorBalance(color, hslColor, vec3(0.0), vec3(0.0, 0.12, 0.2), vec3(-0.12, 0.0, 0.2), true);

	color = vignette(color);

	color = lensFlare(color, texcoord.st);

	//color = motionBlur(color, texcoord.st, viewPosition);

	gl_FragColor = vec4(color, 1.0);
}