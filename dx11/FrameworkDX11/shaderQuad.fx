//--------------------------------------------------------------------------------------
// 
// Copyright (c) Microsoft Corporation. All rights reserved.
//--------------------------------------------------------------------------------------

// the lighting equations in this code have been taken from https://www.3dgep.com/texturing-lighting-directx-11/
// with some modifications by David White

//--------------------------------------------------------------------------------------
// Constant Buffer Variables
//--------------------------------------------------------------------------------------
cbuffer ConstantBuffer : register(b1)
{
    matrix World;
    matrix View;
    matrix Projection;
    float4 vOutputColor;
}

Texture2D txDiffuse : register(t0);

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

float4 MotionBlurr(float2 tc)
{
    float2 texCoords = tc;
    float zOverW = txDiffuse.Sample(samLinear, texCoords);
    
    float4 H = float4(texCoords.x * 2 - 1, (1 - texCoords.y) * 2 - 1, zOverW, 1);
    float4 D = mul(H, Projection);
    
    float4 worldPos = D / D.w;
    
    float4 currentPos = H;
    float4 previousPos = mul(worldPos, Projection);
    
    previousPos /= previousPos.w;
    
    float2 velocity = (currentPos - previousPos) / 2.0;
    
    float4 colour = txDiffuse.Sample(samLinear, texCoords);
    texCoords += velocity;
    
    int numberOfSamples = 10;
    
    for (int i = 1; i < numberOfSamples; ++i, texCoords += velocity)
    {
        float4 currentColour = txDiffuse.Sample(samLinear, texCoords);
        colour += currentColour;
    }
    
    float4 finalColour = colour / numberOfSamples;
    
    return finalColour;
}
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
//--------------------------------------------------------------------------------------
// Pixel Shader
//--------------------------------------------------------------------------------------
float4 QuadPS(QuadVS_Output Input) : SV_TARGET
{
   // float4 motionBlur = MotionBlurr(Input.Tex);
   float4 vColour = txDiffuse.Sample(samLinear, Input.Tex);

    return vColour;
}
