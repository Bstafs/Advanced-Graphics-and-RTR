//--------------------------------------------------------------------------------------
// 
// Copyright (c) Microsoft Corporation. All rights reserved.
//--------------------------------------------------------------------------------------

// the lighting equations in this code have been taken from https://www.3dgep.com/texturing-lighting-directx-11/
// with some modifications by David White

//--------------------------------------------------------------------------------------
// Constant Buffer Variables
//--------------------------------------------------------------------------------------
Texture2D txDiffuse : register(t0);

cbuffer BlurBuffer : register(b0)
{
    bool horizontal;
    float3 padding;
};

SamplerState bloomBlur : register(s0);

#define MAX_LIGHTS 1
// Light types.
#define DIRECTIONAL_LIGHT 0
#define POINT_LIGHT 1
#define SPOT_LIGHT 2
//--------------------------------------------------------------------------------------
struct QuadVS_Input
{
    float4 Pos : POSITION;
    float2 Tex : TEXCOORD0;
};

struct QuadVS_Output
{
    float4 Pos : SV_POSITION;
    float2 Tex : TEXCOORD0;
};

//--------------------------------------------------------------------------------------
// Vertex Shader
//--------------------------------------------------------------------------------------
QuadVS_Output QuadVS(QuadVS_Input Input)
{
    QuadVS_Output Output;
    Output.Pos = Input.Pos;
    Output.Tex = Input.Tex;
    return Output;
}

float3 square(float3 x)
{
    return x * x;
}

float3 GuassianBlur(float2 texCoords)
{
    float weight[5] = { 0.227027, 0.1945946, 0.1216216, 0.054054, 0.016216 };
    
    float3 vColour = txDiffuse.Sample(bloomBlur, texCoords).rgb * weight[0];
    float2 textureOffset = 1 / txDiffuse.Sample(bloomBlur, 0.0);
    
    if (horizontal == true)
    {
        for (int i = 1; i < 5; i++)
        {
            vColour += txDiffuse.Sample(bloomBlur, texCoords + float2(textureOffset.x, 0.0)).rgb * weight[i];
            vColour += txDiffuse.Sample(bloomBlur, texCoords - float2(textureOffset.x, 0.0)).rgb * weight[i];
        }
    }
    else if (horizontal == false)
    {
        for (int i = 1; i < 5; i++)
        {
            vColour += txDiffuse.Sample(bloomBlur, texCoords + float2(textureOffset.y, 0.0)).rgb * weight[i];
            vColour += txDiffuse.Sample(bloomBlur, texCoords - float2(textureOffset.y, 0.0)).rgb * weight[i];
        }
    }
    
    return vColour;
}

//--------------------------------------------------------------------------------------
// Pixel Shader
//--------------------------------------------------------------------------------------
float4 QuadPS(QuadVS_Output Input) : SV_TARGET
{
    float3 vBlur = GuassianBlur(Input.Tex).rgb;
   
    return float4(vBlur, 1.0);
}

