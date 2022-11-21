//--------------------------------------------------------------------------------------
// 
// Copyright (c) Microsoft Corporation. All rights reserved.
//--------------------------------------------------------------------------------------

// the lighting equations in this code have been taken from https://www.3dgep.com/texturing-lighting-directx-11/
// with some modifications by David White

Texture2D txNormal : register(t0);
Texture2D txDiffuse : register(t1);
Texture2D txSpecular : register(t2);
Texture2D txPosition : register(t3);
Texture2D txAmbient : register(t4);
Texture2D txEmissive : register(t5);

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

cbuffer LightProperties : register(b0)
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

};

struct PS_INPUT
{
    float4 Pos : SV_POSITION;
};

void GetGBufferAttributes(in float2 screenPos, out float3 normal, out float3 position, out float3 diffuse, out float3 specular,out float3 emissive, out float3 ambient,out float specularPower)
{
    int3 sampleIndices = int3(screenPos.xy, 0);
    normal = txNormal.Load(sampleIndices).xyz;
    position = txPosition.Load(sampleIndices).xyz;
    diffuse = txDiffuse.Load(sampleIndices).xyz;
    emissive = txEmissive.Load(sampleIndices).xyz;
    ambient = txAmbient.Load(sampleIndices).xyz;
    float4 spec = txSpecular.Load(sampleIndices);
    
    specular = spec.xyz;
    specularPower = spec.w;
   
}


float4 DoSpecular(Light lightObject, float3 vertexToEye, float3 lightDirectionToVertex, float3 Normal, float specPow)
{
    float4 lightDir = float4(normalize(-lightDirectionToVertex), 1);
    vertexToEye = normalize(vertexToEye);

    float lightIntensity = saturate(dot(Normal, lightDir));
    float4 specular = float4(0, 0, 0, 0);
    if (lightIntensity > 0.0f)
    {
        float3 reflection = normalize(2 * lightIntensity * Normal - lightDir);
        specular = pow(saturate(dot(reflection, vertexToEye)), specPow); // 32 = specular power
    }

    return specular;
}

float DoAttenuation(Light light, float d)
{
    return 1.0f / (light.ConstantAttenuation + light.LinearAttenuation * d + light.QuadraticAttenuation * d * d);
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
float4 PS(PS_INPUT input) : SV_Target
{
    float3 normal;
    float3 position;
    float3 diffuse;
    float3 specular;
    float3 ambient;
    float3 emissive;
    float specularPower;
    
    GetGBufferAttributes(input.Pos.xy, normal, position, diffuse, specular, emissive, ambient, specularPower);
    
    float3 vertexToEye = EyePosition.xyz - position.xyz;
    float3 vertexToLight = Lights[0].Position - position.xyz;
    
    float distance = length(vertexToLight);
    vertexToLight = vertexToLight / distance;
    
    float attenuation = DoAttenuation(Lights[0], distance);
    float4 spec = DoSpecular(Lights[0], vertexToEye, -vertexToLight, normal, specularPower);
    
    float lightAmount = saturate(dot(normal, vertexToLight));
    float3 color = lightAmount * Lights[0].Color * attenuation;
   
    float3 finalDiffuse = color * diffuse;
    float3 finalSpecular = spec * diffuse * attenuation;
    float3 finalAmbient = (ambient * GlobalAmbient) * diffuse;
    
    float4 finalColor = float4(finalDiffuse, 1.0);
    
    return finalColor;
}