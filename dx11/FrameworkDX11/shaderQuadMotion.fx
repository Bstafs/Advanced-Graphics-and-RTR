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

SamplerState motionBlur : register(s0);

cbuffer MotionBlurBuffer : register(b0)
{
    matrix World;
    matrix View;
    matrix Projection;
    matrix InverseProjection;
    matrix PreviousProjection;
    float4 vOutputColor;
}

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

float4 MotionBlur(float2 texCoords)
{
    float numSamples = 15;
    float zOverW = txDiffuse.Sample(motionBlur, texCoords);
    float4 H = float4(texCoords.x * 2 - 1, (1 - texCoords.y) * 2 - 1, zOverW, 1);
    float4 D = mul(H, InverseProjection);
    float4 worldPos = D / D.w;
    float4 currentPos = H;
    float4 prevPos = mul(worldPos, PreviousProjection);
    prevPos /= prevPos.w;
    float2 velocity = (currentPos - prevPos) / 2.0f;

    float4 colour = txDiffuse.Sample(motionBlur, texCoords);
    texCoords += velocity;
    
    for (int i = 1; i < numSamples; ++i, texCoords += velocity)
    {
        float4 currentColour = txDiffuse.Sample(motionBlur, texCoords);
        
        colour += currentColour;
    }

    return colour / numSamples;
}

//--------------------------------------------------------------------------------------
// Pixel Shader
//--------------------------------------------------------------------------------------
float4 QuadPS(QuadVS_Output Input) : SV_TARGET
{
    float4 result = MotionBlur(Input.Tex);
    
    return result;
}

