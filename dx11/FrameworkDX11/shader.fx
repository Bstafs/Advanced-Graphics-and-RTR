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
    int iEffectID;

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
    attenuation = 1;

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

float3 VectorToTangentSpace(float3 VectorV, float3x3 TBN_inv)
{
    float3 tangentSpaceNormal = normalize(mul(VectorV, TBN_inv));
    return tangentSpaceNormal;
}

float2 ParallaxMapping(float2 texCoords, float3 viewDir)
{
    float heightScale = 0.05f;
    float height = txParrallax.Sample(samLinear, texCoords).x;
    float2 p = viewDir.xy / viewDir.z * (height * heightScale);
    return texCoords - p;
}

float2 ParallaxSteepMapping(float2 texCoords, float3 norm, float3 viewDir)
{
    // Number of layers frim angle between texCoords and Norm
    float minLayers = 5.0f;
    float maxLayers = 15.0f;
    float numLayers = lerp(maxLayers, minLayers, max(dot(float3(0.0, 0.0, 1.0), viewDir), 0.0));

    // Height of each layer
    float layerHeight = 1.0 / numLayers;

    //Depth of each layer
    float currentLayerHeight = 0.0;
    float2 P = viewDir.xy * 0.1f; // 0.1f = height (temp value) Need to add a variable in buffer
    
    // Shift of texture coordinates for each iteration
    float2 deltaTexCoords = P / numLayers;
    
    // Current texture coords
    float2 currentTexCoords = texCoords;
    float parallaxMap = txParrallax.Sample(samLinear, currentTexCoords).x;

    // While point is above surface
    [loop] // For some reason hlsl can't tell this is a loop / Complains about compiling and so we have to "unroll it" 
    while (currentLayerHeight < parallaxMap)
    {
        currentTexCoords -= deltaTexCoords;
        parallaxMap = txParrallax.Sample(samLinear, currentTexCoords).x;
        currentLayerHeight += layerHeight;
    }
    
    // Final results and Calculations
    float2 prevTexCoords = currentTexCoords + deltaTexCoords;

    // Calculating after and before depth of mapping
    float afterDepth = parallaxMap - currentLayerHeight;
    float beforeDepth = txParrallax.Sample(samLinear, prevTexCoords).r - currentLayerHeight + layerHeight;
    float weight = afterDepth / (afterDepth - beforeDepth);
  
    // Adding depth to final texCoords
    float2 finalTexCoords = prevTexCoords * weight + currentTexCoords * (1.0 - weight);

    // returning Final Coords
    return finalTexCoords;
}

float2 ParallaxReliefMapping(float2 texCoords, float3 norm, float3 viewDir)
{
    // Number of layers frim angle between texCoords and Norm
    float minLayers = 5.0f;
    float maxLayers = 15.0f;
    float numLayers = lerp(maxLayers, minLayers, max(dot(float3(0.0, 0.0, 1.0), viewDir), 0.0));

    // Height of each layer
    float layerHeight = 1.0 / numLayers;

    //Depth of each layer
    float currentLayerHeight = 0.0;
    float2 P = viewDir.xy * 0.1f; // 0.1f = height (temp value) Need to add a variable in buffer
    
    // Shift of texture coordinates for each iteration
    float2 deltaTexCoords = P / numLayers;
    
    // Current texture coords
    float2 currentTexCoords = texCoords;
    float parallaxMap = txParrallax.Sample(samLinear, currentTexCoords).x;

    // While point is above surface
    [loop] // For some reason hlsl can't tell this is a loop / Complains about compiling and so we have to "unroll it" 
    while (currentLayerHeight < parallaxMap)
    {
        currentTexCoords -= deltaTexCoords;
        parallaxMap = txParrallax.Sample(samLinear, currentTexCoords).x;
        currentLayerHeight += layerHeight;
    }
    
    float dTexCord = deltaTexCoords / 2.0f;
    float deltaHeight = layerHeight / 2.0f;
    
    currentTexCoords += deltaTexCoords;
    currentLayerHeight -= deltaHeight;
    
    const int numSearches = 5;
    for (int i = 0; i < numSearches; i++)
    {
        deltaTexCoords /= 2.0f;
        deltaHeight /= 2.0f;
   
        float heightFromTexture = txParrallax.Sample(samLinear, currentTexCoords).r;
        
        if (heightFromTexture > currentLayerHeight)
        {
            currentTexCoords -= deltaTexCoords;
            currentLayerHeight += deltaTexCoords;
        }
        else
        {
            currentTexCoords += deltaHeight;
            currentTexCoords -= deltaHeight;
        }

    }
    // returning Final Coords
    return currentTexCoords;
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

	// multiply the normal by the world transform (to go from model space to world space)
	//output.Norm = mul(float4(input.Norm, 1), World).xyz;

    float3 vertexToEye = EyePosition - worldPos.xyz;
    float3 vertexToLight = Lights[0].Position - worldPos.xyz;

	// TBN Matrix
    float3 T = normalize(mul(input.Tang, World));
    float3 B = normalize(mul(input.BiNorm, World));
    float3 N = normalize(mul(input.Norm, World));
    float3x3 TBN = float3x3(T, B, N);
    float3x3 TBN_inv = transpose(TBN);

	// Set To Lighting To Tangent Space
    output.eyeVectorTS = VectorToTangentSpace(vertexToEye.xyz, TBN_inv);
    output.lightVectorTS = VectorToTangentSpace(vertexToLight.xyz, TBN_inv);
    output.eyePosTS = VectorToTangentSpace(EyePosition.xyz, TBN_inv);
    output.PosTS = VectorToTangentSpace(worldPos.xyz, TBN_inv);

    return output;
}

//--------------------------------------------------------------------------------------
// Pixel Shader
//--------------------------------------------------------------------------------------

float4 PS(PS_INPUT IN) : SV_TARGET
{
    float3 viewDir = normalize(IN.eyePosTS - IN.PosTS);
 
   // float2 texCoords = IN.Tex; // Normal Mapping
   // float2 texCoords = ParallaxMapping(IN.Tex, viewDir); // Simple Parallax Mapping
   //   float2 texCoords = ParallaxSteepMapping(IN.Tex, IN.Norm, viewDir);
    float2 texCoords = ParallaxReliefMapping(IN.Tex, IN.Norm, viewDir);
    
    //if (texCoords.x > 1.0 || texCoords.y > 1.0 || texCoords.x < 0.0 || texCoords.y < 0.0)
    //    discard;
	
	// Mapping
    float4 bumpMap = txNormal.Sample(samLinear, texCoords);
	
    bumpMap = (bumpMap * 2.0f) - 1.0f;
    bumpMap = float4(normalize(bumpMap.xyz), 1);
	
	// Compute Lighting
    LightingResult lit = ComputeLighting(IN.eyeVectorTS, IN.lightVectorTS, bumpMap);

    float4 texColor = { 1, 1, 1, 1 };

    float4 emissive = Material.Emissive;
    float4 ambient = Material.Ambient * GlobalAmbient;
    float4 diffuse = Material.Diffuse * lit.Diffuse;
    float4 specular = Material.Specular * lit.Specular;

    if (Material.UseTexture)
    {
        texColor = txDiffuse.Sample(samLinear, texCoords);
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
