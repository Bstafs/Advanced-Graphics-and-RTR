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
}

Texture2D txDiffuse : register(t0);
Texture2D txNormal : register(t1);
Texture2D txParrallax : register(t2);
Texture2D txSpecular : register(t3);
Texture2D txPosition : register(t4);
Texture2D txAmbient : register(t5);
Texture2D txEmissive : register(t6);

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
    float4 Emissive; // 16 bytes
	//----------------------------------- (16 byte boundary)
    float4 Ambient; // 16 bytes
	//------------------------------------(16 byte boundary)
    float4 Diffuse; // 16 bytes
	//----------------------------------- (16 byte boundary)
    float4 Specular; // 16 bytes
	//----------------------------------- (16 byte boundary)
    float SpecularPower; // 4 bytes
    bool UseTexture; // 4 bytes
    float2 Padding; // 8 bytes
	//----------------------------------- (16 byte boundary)
}; // Total:               // 80 bytes ( 5 * 16 )

cbuffer MaterialProperties : register(b1)
{
    _Material Material;
};

struct Light
{
    float4 Position; // 16 bytes
	//----------------------------------- (16 byte boundary)
    float4 Direction; // 16 bytes
	//----------------------------------- (16 byte boundary)
    float4 Color; // 16 bytes
	//----------------------------------- (16 byte boundary)
    float SpotAngle; // 4 bytes
    float ConstantAttenuation; // 4 bytes
    float LinearAttenuation; // 4 bytes
    float QuadraticAttenuation; // 4 bytes
	//----------------------------------- (16 byte boundary)
    int LightType; // 4 bytes
    bool Enabled; // 4 bytes
    int2 Padding; // 8 bytes
	//----------------------------------- (16 byte boundary)
}; // Total:                           // 80 bytes (5 * 16)

cbuffer LightProperties : register(b2)
{
    float4 EyePosition; // 16 bytes
	//----------------------------------- (16 byte boundary)
    float4 GlobalAmbient; // 16 bytes
	//----------------------------------- (16 byte boundary)
    Light Lights[MAX_LIGHTS]; // 80 * 8 = 640 bytes
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
    float3 PosTS : POSTS;
    float3 eyePosTS : EYEPOSTS;
    float3 normTS : NORMTS;
    float3x3 TBN : TBN;
};

struct PS_OUTPUT
{
    float4 Normal : SV_Target0;
    float4 Diffuse : SV_Target1;
    float4 Specular : SV_Target2;
    float4 Position : SV_Target3;
    float4 Ambient : SV_Target4;
    float4 Emissive : SV_Target5;
};

float4 VSMain(in float4 Position : POSITION) : SV_Position
{
    return Position;
}

void GetGBufferAttributes(in float2 screenPos, out float4 normal, out float4 position, out float4 diffuse, out float4 specular, out float specularPower)
{
    int3 sampleIndices = int3(screenPos.xy, 0);
    normal = txNormal.Load(sampleIndices).xyzw;
    position = txPosition.Load(sampleIndices).xyzw;
    diffuse = txDiffuse.Load(sampleIndices).xyzw;
    float4 spec = txSpecular.Load(sampleIndices);
    
    specular = spec.xyzw;
    specularPower = spec.w;
   
}

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
        float3 reflection = normalize(2 * lightIntensity * Normal - lightDir);
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

LightingResult DoPointLight(Light light, float3 eyeVectorTS, float3 lightVectorTS, float3 N)
{
    LightingResult result;

    float3 LightDirectionToVertex = -lightVectorTS;
    float distance = length(LightDirectionToVertex);
    LightDirectionToVertex = LightDirectionToVertex / distance;

    distance = length(lightVectorTS);
    lightVectorTS = lightVectorTS / distance;

    float attenuation = DoAttenuation(light, distance);
    //attenuation = 1;

    result.Diffuse = DoDiffuse(light, lightVectorTS, N) * attenuation;
    result.Specular = DoSpecular(light, eyeVectorTS, LightDirectionToVertex, N) * attenuation;

    return result;
}

LightingResult ComputeLighting(float3 eyeVectorTS, float3 lightVectorTS, float3 N)
{
  //  float3 vertexToEye = normalize(EyePosition - vertexPos).xyz;

    LightingResult totalResult = { { 0, 0, 0, 0 }, { 0, 0, 0, 0 } };

	[unroll]
    for (int i = 0; i < MAX_LIGHTS; ++i)
    {
        LightingResult result = { { 0, 0, 0, 0 }, { 0, 0, 0, 0 } };

        if (!Lights[i].Enabled) 
            continue;
		
        result = DoPointLight(Lights[i], eyeVectorTS, lightVectorTS, N);
		
        totalResult.Diffuse += result.Diffuse;
        totalResult.Specular += result.Specular;
    }

    totalResult.Diffuse = saturate(totalResult.Diffuse);
    totalResult.Specular = saturate(totalResult.Specular);

    return totalResult;
}

//--------------------------------------------------------------------------------------
// Vertex Shader
//--------------------------------------------------------------------------------------
PS_INPUT VS(VS_INPUT input)
{
    PS_INPUT output;
    output.Pos = input.Pos;
    return output;
}
//--------------------------------------------------------------------------------------
// Pixel Shader
//--------------------------------------------------------------------------------------
float4 PSMain(in float4 screenPos : SV_Position) : SV_Target0
{
    float4 normal;
    float4 position;
    float4 diffuse;
    float4 specular;
    float specularPower;
    
    GetGBufferAttributes(screenPos.xy, normal, position, diffuse, specular, specularPower);

    LightingResult lit = ComputeLighting(normal, position, specularPower);
    
    float4 emissive = Material.Emissive;
    float4 ambient = Material.Ambient * GlobalAmbient;
    diffuse = Material.Diffuse * lit.Diffuse;
    specular = Material.Specular * lit.Specular;
    
    float4 finalColor = (emissive + ambient + diffuse + specular);
    
    return finalColor;

}