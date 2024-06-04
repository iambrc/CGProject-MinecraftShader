#version 120

uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform mat4 gbufferModelViewInverse;
uniform int worldTime;
uniform float rainStrength;

varying vec4 texcoord;
varying vec3 lightPosition;
varying vec3 worldSunPosition;
varying vec3 cloudBase1;
varying vec3 cloudBase2;
varying vec3 cloudLight1;
varying vec3 cloudLight2;
varying float extShadow;
varying float isNight;
varying vec3 mySkyColor;
varying vec3 mySunColor;

#define SUNRISE 23200
#define SUNSET 12800
#define FADE_START 500
#define FADE_END 250

#define SUNSET_START 11500.0
#define SUNSET_MID1 12300.0
#define SUNSET_MID2 13600.0
#define SUNSET_MID3 14200.0
#define SUNSET_END 14500.0
#define SUNRISE_START 21000.0
#define SUNRISE_MID1 22000.0
#define SUNRISE_MID2 22500.0
#define SUNRISE_MID3 23500.0
#define SUNRISE_END 24000.0

const vec3 BASE1_DAY = vec3(1.0,0.95,0.9), BASE2_DAY = vec3(0.3,0.315,0.325);
const vec3 LIGHTING1_DAY = vec3(0.7,0.75,0.8), LIGHTING2_DAY = vec3(1.8, 1.6, 1.35);

const vec3 BASE1_SUNSET = vec3(0.6,0.6,0.72), BASE2_SUNSET = vec3(0.1,0.1,0.1);
const vec3 LIGHTING1_SUNSET = vec3(0.63,0.686,0.735), LIGHTING2_SUNSET = vec3(1.2, 0.84, 0.72);

const vec3 BASE1_NIGHT_NOMOON = vec3(0.27,0.27,0.324), BASE2_NIGHT_NOMOON = vec3(0.05,0.05,0.1);
const vec3 LIGHTING1_NIGHT_NOMOON = vec3(1.5,1.5,1.5), LIGHTING2_NIGHT_NOMOON = vec3(0.8,0.8,0.9);

const vec3 BASE1_NIGHT = vec3(0.075,0.075,0.09), BASE2_NIGHT = vec3(0.05,0.05,0.1);
const vec3 LIGHTING1_NIGHT = vec3(6.0,6.0,6.3), LIGHTING2_NIGHT = vec3(1.0,1.0,1.0);

vec3 sunColorArr[] = vec3[](
    vec3(255.0/255, 140.0/255, 19.0/255),      // 0-1000
    vec3(255.0/255, 140.0/255, 19.0/255),      // 1000 - 2000
    vec3(251.0/255, 172.0/255, 19.0/255),      // 2000 - 3000
    vec3(251.0/255, 172.0/255, 19.0/255),      // 3000 - 4000
    vec3(251.0/255, 172.0/255, 19.0/255),      // 4000 - 5000 
    vec3(251.0/255, 172.0/255, 19.0/255),      // 5000 - 6000
    vec3(251.0/255, 172.0/255, 19.0/255),      // 6000 - 7000
    vec3(251.0/255, 172.0/255, 19.0/255),      // 7000 - 8000
    vec3(251.0/255, 172.0/255, 19.0/255),      // 8000 - 9000
    vec3(251.0/255, 172.0/255, 19.0/255),      // 9000 - 10000
    vec3(251.0/255, 172.0/255, 19.0/255),      // 10000 - 11000
    vec3(251.0/255, 172.0/255, 19.0/255),      // 11000 - 12000
    vec3(251.0/255, 172.0/255, 19.0/255),      // 12000 - 13000
    vec3(252.0/255, 254.0/255, 218.0/255),      // 13000 - 14000
    vec3(252.0/255, 254.0/255, 218.0/255),      // 14000 - 15000
    vec3(252.0/255, 254.0/255, 218.0/255),      // 15000 - 16000
    vec3(252.0/255, 254.0/255, 218.0/255),      // 16000 - 17000
    vec3(252.0/255, 254.0/255, 218.0/255),      // 17000 - 18000
    vec3(252.0/255, 254.0/255, 218.0/255),      // 18000 - 19000
    vec3(252.0/255, 254.0/255, 218.0/255),      // 19000 - 20000
    vec3(252.0/255, 254.0/255, 218.0/255),      // 20000 - 21000
    vec3(252.0/255, 254.0/255, 218.0/255),      // 21000 - 22000
    vec3(252.0/255, 254.0/255, 218.0/255),      // 22000 - 23000
    vec3(252.0/255, 254.0/255, 218.0/255)       // 23000 - 24000(0)
);

vec3 skyColorArr[] = vec3[](
    vec3(227.0/255, 206.0/255, 180.0/255),        // 0-1000
    vec3(194.0/255, 201.0/255, 180.0/255),        // 1000 - 2000
    vec3(95.0/255, 175.0/255, 200.0/255),        // 2000 - 3000
    vec3(95.0/255, 175.0/255, 200.0/255),        // 3000 - 4000
    vec3(95.0/255, 175.0/255, 200.0/255),        // 4000 - 5000 
    vec3(95.0/255, 175.0/255, 200.0/255),        // 5000 - 6000
    vec3(95.0/255, 175.0/255, 200.0/255),        // 6000 - 7000
    vec3(95.0/255, 175.0/255, 200.0/255),        // 7000 - 8000
    vec3(095.0/255, 175.0/255, 200.0/255),        // 8000 - 9000
    vec3(99.0/255, 176.0/255, 223.0/255),        // 9000 - 10000
    vec3(137.0/255, 184.0/255, 222.0/255),        // 10000 - 11000
    vec3(200.0/255, 202.0/255, 222.0/255),        // 11000 - 12000
    vec3(227.0/255, 130.0/255, 130.0/255),        // 12000 - 13000
    vec3(50.0/255, 50.0/255, 100.0/255),      // 13000 - 14000
    vec3(50.0/255, 50.0/255, 100.0/255),      // 14000 - 15000
    vec3(50.0/255, 50.0/255, 100.0/255),      // 15000 - 16000
    vec3(20.0/255, 20.0/255, 50.0/255),      // 16000 - 17000
    vec3(20.0/255, 20.0/255, 50.0/255),      // 17000 - 18000
    vec3(20.0/255, 20.0/255, 50.0/255),      // 18000 - 19000
    vec3(20.0/255, 20.0/255, 50.0/255),      // 19000 - 20000
    vec3(50.0/255, 50.0/255, 100.0/255),      // 20000 - 21000
    vec3(120.0/255, 110.0/255, 150.0/255),      // 21000 - 22000
    vec3(182.0/255, 162.0/255, 197.0/255),      // 22000 - 23000
    vec3(227.0/255, 206.0/255, 219.0/255)       // 23000 - 24000(0)
);

void main() {
	gl_Position = ftransform();
	texcoord = gl_MultiTexCoord0;
	if(worldTime >= SUNRISE - FADE_START && worldTime <= SUNRISE + FADE_START)
	{
		extShadow = 1.0;
		if(worldTime < SUNRISE - FADE_END) extShadow -= float(SUNRISE - FADE_END - worldTime) / float(FADE_END); else if(worldTime > SUNRISE + FADE_END)
			extShadow -= float(worldTime - SUNRISE - FADE_END) / float(FADE_END);
	}
	else if(worldTime >= SUNSET - FADE_START && worldTime <= SUNSET + FADE_START)
	{
		extShadow = 1.0;
		if(worldTime < SUNSET - FADE_END) extShadow -= float(SUNSET - FADE_END - worldTime) / float(FADE_END); else if(worldTime > SUNSET + FADE_END)
			extShadow -= float(worldTime - SUNSET - FADE_END) / float(FADE_END);
	}
	else
		extShadow = 0.0;
	
	if(worldTime < SUNSET || worldTime > SUNRISE)
		lightPosition = normalize(sunPosition);
	else
		lightPosition = normalize(moonPosition);
		
	worldSunPosition = normalize((gbufferModelViewInverse * vec4(sunPosition, 0.0)).xyz);
	
	float fTime = float(worldTime);
	if(fTime > SUNSET_START && fTime <= SUNSET_MID1)
	{
		float n = smoothstep(SUNSET_START, SUNSET_MID1, fTime);
		cloudBase1 = mix(BASE1_DAY, BASE1_SUNSET, n);
		cloudBase2 = mix(BASE2_DAY, BASE2_SUNSET, n);
		cloudLight1 = mix(LIGHTING1_DAY, LIGHTING1_SUNSET, n);
		cloudLight2 = mix(LIGHTING2_DAY, LIGHTING2_SUNSET, n);
	}
	else if(fTime > SUNSET_MID1 && fTime <= SUNSET_MID2)
	{
		cloudBase1 = BASE1_SUNSET;
		cloudBase2 = BASE2_SUNSET;
		cloudLight1 = LIGHTING1_SUNSET;
		cloudLight2 = LIGHTING2_SUNSET;
	}
	else if(fTime > SUNSET_MID2 && fTime <= SUNSET_MID3)
	{
		float n = smoothstep(SUNSET_MID2, SUNSET_MID3, fTime);
		cloudBase1 = mix(BASE1_SUNSET, BASE1_NIGHT_NOMOON, n);
		cloudBase2 = mix(BASE2_SUNSET, BASE2_NIGHT_NOMOON, n);
		cloudLight1 = mix(LIGHTING1_SUNSET, LIGHTING1_NIGHT_NOMOON, n);
		cloudLight2 = mix(LIGHTING2_SUNSET, LIGHTING2_NIGHT_NOMOON, n);
	}
	else if(fTime > SUNSET_MID3 && fTime <= SUNSET_END)
	{
		float n = smoothstep(SUNSET_MID3, SUNSET_END, fTime);
		cloudBase1 = mix(BASE1_NIGHT_NOMOON, BASE1_NIGHT, n);
		cloudBase2 = mix(BASE2_NIGHT_NOMOON, BASE2_NIGHT, n);
		cloudLight1 = mix(LIGHTING1_NIGHT_NOMOON, LIGHTING1_NIGHT, n);
		cloudLight2 = mix(LIGHTING2_NIGHT_NOMOON, LIGHTING2_NIGHT, n);
	}
	else if(fTime > SUNSET_END && fTime <= SUNRISE_START)
	{
		cloudBase1 = BASE1_NIGHT;
		cloudBase2 = BASE2_NIGHT;
		cloudLight1 = LIGHTING1_NIGHT;
		cloudLight2 = LIGHTING2_NIGHT;
	}
	else if(fTime > SUNRISE_START && fTime <= SUNRISE_MID1)
	{
		float n = smoothstep(SUNRISE_START, SUNRISE_MID1, fTime);
		cloudBase1 = mix(BASE1_NIGHT, BASE1_NIGHT_NOMOON, n);
		cloudBase2 = mix(BASE2_NIGHT, BASE2_NIGHT_NOMOON, n);
		cloudLight1 = mix(LIGHTING1_NIGHT, LIGHTING1_NIGHT_NOMOON, n);
		cloudLight2 = mix(LIGHTING2_NIGHT, LIGHTING2_NIGHT_NOMOON, n);
	}
	else if(fTime > SUNRISE_MID1 && fTime <= SUNRISE_MID2)
	{
		float n = smoothstep(SUNRISE_MID1, SUNRISE_MID2, fTime);
		cloudBase1 = mix(BASE1_NIGHT_NOMOON, BASE1_SUNSET, n);
		cloudBase2 = mix(BASE2_NIGHT_NOMOON, BASE2_SUNSET, n);
		cloudLight1 = mix(LIGHTING1_NIGHT_NOMOON, LIGHTING1_SUNSET, n);
		cloudLight2 = mix(LIGHTING2_NIGHT_NOMOON, LIGHTING2_SUNSET, n);
	}
	else if(fTime > SUNRISE_MID2 && fTime <= SUNRISE_MID3)
	{
		cloudBase1 = BASE1_SUNSET;
		cloudBase2 = BASE2_SUNSET;
		cloudLight1 = LIGHTING1_SUNSET;
		cloudLight2 = LIGHTING2_SUNSET;
	}
	else if(fTime > SUNRISE_MID3 && fTime <= SUNRISE_END)
	{
		float n = smoothstep(SUNRISE_MID3, SUNRISE_END, fTime);
		cloudBase1 = mix(BASE1_SUNSET, BASE1_DAY, n);
		cloudBase2 = mix(BASE2_SUNSET, BASE2_DAY, n);
		cloudLight1 = mix(LIGHTING1_SUNSET, LIGHTING1_DAY, n);
		cloudLight2 = mix(LIGHTING2_SUNSET, LIGHTING2_DAY, n);
	}
	else
	{
		cloudBase1 = BASE1_DAY;
		cloudBase2 = BASE2_DAY;
		cloudLight1 = LIGHTING1_DAY;
		cloudLight2 = LIGHTING2_DAY;
	}

	int hour = worldTime/1000;
    int next = (hour+1<24)?(hour+1):(0);
    float delta = float(worldTime-hour*1000)/1000;
    mySkyColor = mix(skyColorArr[hour], skyColorArr[next], delta);
    mySunColor = mix(sunColorArr[hour], sunColorArr[next], delta);

    isNight = 0;
    if(12000<worldTime && worldTime<13000) {
        isNight = 1.0 - (13000-worldTime) / 1000.0;
    }
    else if(13000<=worldTime && worldTime<=23000) {
        isNight = 1.0;
    }
    else if(23000<worldTime) {
        isNight = (24000-worldTime) / 1000.0;
    }

    mySkyColor = mix(mySkyColor, vec3(0.7, 0.7, 0.8) * (1-isNight*0.7), rainStrength);
    mySunColor = mix(mySunColor, vec3(0.7, 0.7, 0.8) * (1-isNight*0.5), rainStrength);
}