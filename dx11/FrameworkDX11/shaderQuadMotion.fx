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
    float2 motion = txDiffuse.Sample(motionBlur, texCoords).xy / 2.0;
    float4 color = 0;
    
    color += txDiffuse.Sample(motionBlur, texCoords) * 0.4;
    texCoords -= motion;
    color += txDiffuse.Sample(motionBlur, texCoords) * 0.3;
    texCoords -= motion;
    color += txDiffuse.Sample(motionBlur, texCoords) * 0.2;
    texCoords -= motion;
    color += txDiffuse.Sample(motionBlur, texCoords) * 0.1;
    return color;
}

//--------------------------------------------------------------------------------------
// Pixel Shader
//--------------------------------------------------------------------------------------
float4 QuadPS(QuadVS_Output Input) : SV_TARGET
{
    float4 result = MotionBlur(Input.Tex);
    
    return result;
}

