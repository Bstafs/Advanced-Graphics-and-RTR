//--------------------------------------------------------------------------------------
// 
// Copyright (c) Microsoft Corporation. All rights reserved.
//--------------------------------------------------------------------------------------

// the lighting equations in this code have been taken from https://www.3dgep.com/texturing-lighting-directx-11/
// with some modifications by David White

//--------------------------------------------------------------------------------------
// Constant Buffer Variables
//--------------------------------------------------------------------------------------
cbuffer ConstantBuffer : register(b0)
{
	matrix World;
	matrix View;
	matrix Projection;
	float4 vOutputColor;

	float fHeightScale;
	int nMinSamples;
	int nMaxSamples;
	float pad1;

	float fNearDepth;
	float fFarDepth;
	float2 pad0;
}

Texture2D txDiffuse : register(t0);
Texture2D txNormal : register(t1);
Texture2D txParrallax : register(t2);

SamplerState samLinear : register(s0)
{
	Filter = ANISOTROPIC;
	MaxAnisotropy = 4;

	AddressU = WRAP;
	AddressV = WRAP;
};

#define MAX_LIGHTS 1
// Light types.
#define DIRECTIONAL_LIGHT 0
#define POINT_LIGHT 1
#define SPOT_LIGHT 2

struct _Material
{
	float4  Emissive;       // 16 bytes
	//----------------------------------- (16 byte boundary)
	float4  Ambient;        // 16 bytes
	//------------------------------------(16 byte boundary)
	float4  Diffuse;        // 16 bytes
	//----------------------------------- (16 byte boundary)
	float4  Specular;       // 16 bytes
	//----------------------------------- (16 byte boundary)
	float   SpecularPower;  // 4 bytes
	bool    UseTexture;     // 4 bytes
	float2  Padding;        // 8 bytes
	//----------------------------------- (16 byte boundary)
};  // Total:               // 80 bytes ( 5 * 16 )

cbuffer MaterialProperties : register(b1)
{
	_Material Material;
};

struct Light
{
	float4      Position;               // 16 bytes
	//----------------------------------- (16 byte boundary)
	float4      Direction;              // 16 bytes
	//----------------------------------- (16 byte boundary)
	float4      Color;                  // 16 bytes
	//----------------------------------- (16 byte boundary)
	float       SpotAngle;              // 4 bytes
	float       ConstantAttenuation;    // 4 bytes
	float       LinearAttenuation;      // 4 bytes
	float       QuadraticAttenuation;   // 4 bytes
	//----------------------------------- (16 byte boundary)
	int         LightType;              // 4 bytes
	bool        Enabled;                // 4 bytes
	int2        Padding;                // 8 bytes
	//----------------------------------- (16 byte boundary)
};  // Total:                           // 80 bytes (5 * 16)

cbuffer LightProperties : register(b2)
{
	float4 EyePosition;                 // 16 bytes
	//----------------------------------- (16 byte boundary)
	float4 GlobalAmbient;               // 16 bytes
	//----------------------------------- (16 byte boundary)
	Light Lights[MAX_LIGHTS];           // 80 * 8 = 640 bytes
};

//--------------------------------------------------------------------------------------
struct VS_INPUT
{
	float4 Pos : POSITION;
	float3 Norm : NORMAL;
	float2 Tex : TEXCOORD0;
	float3 Tang : TANGENT;
	float3 BiNorm : BINORMAL;
};

struct PS_INPUT
{
	float4 Pos : SV_POSITION;
	float4 worldPos : POSITION;
	float3 Norm : NORMAL;
	float2 Tex : TEXCOORD0;

	float3 eyeVectorTS : EYEVECTORTS;
	float3 lightVectorTS : LIGHTVECTORTS;
};


float4 DoDiffuse(Light light, float3 L, float3 N)
{
	float NdotL = max(0, dot(N, L));
	return light.Color * NdotL;
}

float4 DoSpecular(Light lightObject, float3 vertexToEye, float3 lightDirectionToVertex, float3 Normal)
{
	float4 lightDir = float4(normalize(-lightDirectionToVertex), 1);
	vertexToEye = normalize(vertexToEye);

	float lightIntensity = saturate(dot(Normal, lightDir));
	float4 specular = float4(0, 0, 0, 0);
	if (lightIntensity > 0.0f)
	{
		float3  reflection = normalize(2 * lightIntensity * Normal - lightDir);
		specular = pow(saturate(dot(reflection, vertexToEye)), Material.SpecularPower); // 32 = specular power
	}

	return specular;
}

float DoAttenuation(Light light, float d)
{
	return 1.0f / (light.ConstantAttenuation + light.LinearAttenuation * d + light.QuadraticAttenuation * d * d);
}

struct LightingResult
{
	float4 Diffuse;
	float4 Specular;
};

LightingResult DoPointLight(Light light, float3 vertexToEye, float4 vertexPos, float3 N)
{
	LightingResult result;

	float3 LightDirectionToVertex = (vertexPos - light.Position).xyz;
	float distance = length(LightDirectionToVertex);
	LightDirectionToVertex = LightDirectionToVertex / distance;

	float3 vertexToLight = (light.Position - vertexPos).xyz;
	distance = length(vertexToLight);
	vertexToLight = vertexToLight / distance;

	float attenuation = DoAttenuation(light, distance);
	attenuation = 1;


	result.Diffuse = DoDiffuse(light, vertexToLight, N) * attenuation;
	result.Specular = DoSpecular(light, vertexToEye, LightDirectionToVertex, N) * attenuation;

	return result;
}

LightingResult ComputeLighting(float4 vertexPos, float3 N)
{
	float3 vertexToEye = normalize(EyePosition - vertexPos).xyz;

	LightingResult totalResult = { { 0, 0, 0, 0 },{ 0, 0, 0, 0 } };

	[unroll]
	for (int i = 0; i < MAX_LIGHTS; ++i)
	{
		LightingResult result = { { 0, 0, 0, 0 },{ 0, 0, 0, 0 } };

		if (!Lights[i].Enabled)
			continue;

		result = DoPointLight(Lights[i], vertexToEye, vertexPos, N);

		totalResult.Diffuse += result.Diffuse;
		totalResult.Specular += result.Specular;
	}

	totalResult.Diffuse = saturate(totalResult.Diffuse);
	totalResult.Specular = saturate(totalResult.Specular);

	return totalResult;
}

float3 VectorToTangentSpace(float3 VectorV, float3x3 TBN_inv)
{
	float3 tangentSpaceNormal = normalize(mul(VectorV, TBN_inv));
	return tangentSpaceNormal;
}

float2 SimpleParallax(float2 texCoord, float3 toEye)
{
	float height = txDiffuse.Sample(samLinear, texCoord).r;
	//assumed that scaled height = -biased height -> h * s + b = h * s - s = s(h - 1)
	//because in presentation it states that reasonable scale value = 0.02, and bias = [-0.01, -0.02]
	float heightSB = fHeightScale * (height - 1.0);

	float2 parallax = toEye.xy * heightSB;

	return (texCoord + parallax);
}

float2 ParallaxOcclusion(float2 texCoord, float3 normal, float3 toEye)
{
	//set up toEye vector in tangent space
	float3 toEyeTS = -toEye;

	//calculate the maximum of parallax shift
	float2 parallaxLimit = fHeightScale * toEyeTS.xy;

	//calculate number of samples
	//normal = (0, 0, 1) in tangent space essentially, if dot product converges to 0, take more samples because it means view vec and normal are perpendicular
	int numSamples = (int)lerp(nMaxSamples, nMinSamples, abs(dot(toEyeTS, normal)));
	float zStep = 1.0f / (float)numSamples;

	float2 heightStep = zStep * parallaxLimit;

	float2 dx = ddx(texCoord);
	float2 dy = ddy(texCoord);

	//init loop variables
	int currSample = 0;
	float2 currParallax = float2(0, 0);
	float2 prevParallax = float2(0, 0);
	float2 finalParallax = float2(0, 0);
	float currZ = 1.0f - heightStep;
	float prevZ = 1.0f;
	float currHeight = 0.0f;
	float prevHeight = 0.0f;

	while (currSample < numSamples + 1)
	{
		currHeight = txDiffuse.SampleGrad(samLinear, texCoord + currParallax, dx, dy).r;

		if (currHeight > currZ)
		{
			float n = prevHeight - prevZ;
			float d = prevHeight - currHeight - prevZ + currZ;
			float ratio = n / d;

			finalParallax = prevParallax + ratio * heightStep;

			currSample = numSamples + 1;
		}
		else
		{
			++currSample;

			prevParallax = currParallax;
			prevZ = currZ;
			prevHeight = currHeight;

			currParallax += heightStep;

			currZ -= zStep;
		}
	}

	return (texCoord + finalParallax);
}

//--------------------------------------------------------------------------------------
// Vertex Shader
//--------------------------------------------------------------------------------------
PS_INPUT VS(VS_INPUT input)
{
	PS_INPUT output = (PS_INPUT)0;
	output.Pos = mul(input.Pos, World);
	output.worldPos = output.Pos;
	output.Pos = mul(output.Pos, View);
	output.Pos = mul(output.Pos, Projection);

	//// multiply the normal by the world transform (to go from model space to world space)
	output.Norm = mul(float4(input.Norm, 0), World).xyz;

	output.Tex = input.Tex;

	return output;
}

//--------------------------------------------------------------------------------------
// Pixel Shader
//--------------------------------------------------------------------------------------

float4 PS(PS_INPUT IN) : SV_TARGET
{
	// Change the range from (0,1) to (-1, 1)
	float4 bumpMap = txNormal.Sample(samLinear, IN.Tex);

	bumpMap = (bumpMap * 2.0f) - 1.0f;
	bumpMap = float4(normalize(bumpMap.xyz), 1); // XYZW

		LightingResult lit = ComputeLighting(IN.worldPos, bumpMap);

		float4 texColor = { 1, 1, 1, 1 };

		float4 emissive = Material.Emissive;
		float4 ambient = Material.Ambient * GlobalAmbient;
		float4 diffuse = Material.Diffuse * lit.Diffuse;
		float4 specular = Material.Specular * lit.Specular;

		if (Material.UseTexture)
		{
			texColor = txDiffuse.Sample(samLinear, IN.Tex);
		}

		float4 finalColor = (emissive + ambient + diffuse + specular) * texColor;

	     return finalColor;
	
}

//--------------------------------------------------------------------------------------
// PSSolid - render a solid color
//--------------------------------------------------------------------------------------
float4 PSSolid(PS_INPUT input) : SV_Target
{
	return vOutputColor;
}
