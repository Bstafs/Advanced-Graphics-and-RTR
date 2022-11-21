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

float3 VectorToTangentSpace(float3 VectorV, float3x3 TBN_inv)
{
    float3 tangentSpaceNormal = normalize(mul(VectorV, TBN_inv));
    return tangentSpaceNormal;
}

float2 ParallaxOcclusionMapping(float2 texCoords,out float parallaxHeight,float3 viewDir)
{
    float minLayers = 15.0f;
    float maxLayers = 30.0f;
    float numLayers = lerp(maxLayers, minLayers, abs(dot(float3(0.0, 0.0, 1.0), viewDir)));

    float layerHeight = 1.0 / numLayers;

    float currentLayerHeight = 0.0;
    float2 P = viewDir.xy / viewDir.z * 0.1f;
    float2 deltaTexCoords = P / numLayers;
    
    float2 currentTexCoords = texCoords;
    float parallaxMap = txParrallax.Sample(samLinear, currentTexCoords).r;

    [unroll(30)]
    while (currentLayerHeight < parallaxMap)
    {
        currentTexCoords -= deltaTexCoords;
        parallaxMap = txParrallax.Sample(samLinear, currentTexCoords).r;
        currentLayerHeight += layerHeight;
    }
    
    float2 prevTexCoords = currentTexCoords + deltaTexCoords;

    float afterHeight = parallaxMap - currentLayerHeight;
    float beforeHeight = txParrallax.Sample(samLinear, prevTexCoords).r - currentLayerHeight + layerHeight;
    float weight = afterHeight / (afterHeight - beforeHeight);
  
    parallaxHeight = currentLayerHeight + beforeHeight * weight + afterHeight * (1.0 - weight);

    float2 finalParallaxHeight = prevTexCoords * weight + currentTexCoords * (1.0 - weight);
    
    return finalParallaxHeight;
}

//--------------------------------------------------------------------------------------
// Vertex Shader
//--------------------------------------------------------------------------------------
PS_INPUT VS(VS_INPUT input)
{
    PS_INPUT output = (PS_INPUT) 0;
    output.Pos = mul(input.Pos, World);
    float4 worldPos = output.Pos;
    output.worldPos = output.Pos;
    output.Pos = mul(output.Pos, View);
    output.Pos = mul(output.Pos, Projection);
    output.Tex = input.Tex;
    float3 vertexToEye = worldPos.xyz - EyePosition.xyz;
    //float3 vertexToLight = worldPos.xyz - Lights[0].Position.xyz;

	// TBN Matrix
    float3 T = normalize(mul(input.Tang, World));
    float3 B = normalize(mul(input.BiNorm, World));
    float3 N = normalize(mul(input.Norm, World));
    
    output.TBN = float3x3(T, B, N);
    
    float3x3 TBN_inv = transpose(output.TBN);

	// Set To Lighting To Tangent Space
    output.eyeVectorTS = VectorToTangentSpace(vertexToEye.xyz, TBN_inv);
    //output.lightVectorTS = VectorToTangentSpace(vertexToLight.xyz, TBN_inv);

    return output;
}
//--------------------------------------------------------------------------------------
// Pixel Shader
//--------------------------------------------------------------------------------------
PS_OUTPUT PS(PS_INPUT IN) : SV_TARGET
{
    PS_OUTPUT output;
    
    float parallaxHeight;
    
    //float2 texCoords = IN.Tex; // Normal Mapping
    float2 texCoords = ParallaxOcclusionMapping(IN.Tex, parallaxHeight, IN.eyeVectorTS);
    
    if (texCoords.x > 1.0 || texCoords.y > 1.0 || texCoords.x < 0.0 || texCoords.y < 0.0)
        discard;
	
	// Mapping
    float4 bumpMap = txNormal.Sample(samLinear, texCoords);
	
    bumpMap = (bumpMap * 2.0f) - 1.0f;
    bumpMap = float4(normalize(bumpMap.xyz), 1);
	
    bumpMap = float4(mul(bumpMap, IN.TBN), 1.0f);
    

    float4 texColor = { 1, 1, 1, 1 };

    output.Emissive = Material.Emissive;
    output.Ambient = Material.Ambient;
    output.Specular = Material.Specular;
    output.Normal = bumpMap;
    output.Position = IN.worldPos;

    if (Material.UseTexture)
    {
        texColor = txDiffuse.Sample(samLinear, texCoords);
    }
    
    output.Diffuse = Material.Diffuse * texColor; 

    return output;
}