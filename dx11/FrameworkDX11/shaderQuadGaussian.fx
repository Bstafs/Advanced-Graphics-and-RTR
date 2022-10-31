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

cbuffer ConstantBuffer : register(b0)
{
    matrix World;
    matrix View;
    matrix Projection;
    float4 vOutputColor;
}

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
    
    float2 Tex1 : TEXCOORD1;
    float2 Tex2 : TEXCOORD2;
    float2 Tex3 : TEXCOORD3;
    float2 Tex4 : TEXCOORD4;
    float2 Tex5 : TEXCOORD5;
    float2 Tex6 : TEXCOORD6;
    float2 Tex7 : TEXCOORD7;
    float2 Tex8 : TEXCOORD8;
    float2 Tex9 : TEXCOORD9;
};

struct QuadVS_Output
{
	float4 Pos : SV_POSITION;
	float2 Tex : TEXCOORD0;
    
    float2 Tex1 : TEXCOORD1;
    float2 Tex2 : TEXCOORD2;
    float2 Tex3 : TEXCOORD3;
    float2 Tex4 : TEXCOORD4;
    float2 Tex5 : TEXCOORD5;
    float2 Tex6 : TEXCOORD6;
    float2 Tex7 : TEXCOORD7;
    float2 Tex8 : TEXCOORD8;
    float2 Tex9 : TEXCOORD9;
};
//--------------------------------------------------------------------------------------
// Vertex Shader
//--------------------------------------------------------------------------------------
QuadVS_Output VertexHorizontalBlur(QuadVS_Input Input)
{
    QuadVS_Output Output;
    float texelSize;
  
    Input.Pos.w = 1.0f;
    
    Output.Pos = mul(Input.Pos, World);
    Output.Pos = mul(Output.Pos, View);
    Output.Pos = mul(Input.Pos, Projection);
    Output.Tex = Input.Tex;
    
    texelSize = 1.0f / 1280.0f;
    
    Output.Tex1 = Input.Tex + float2(texelSize * -4.0f, 0.0f);
    Output.Tex2 = Input.Tex + float2(texelSize * -3.0f, 0.0f);
    Output.Tex3 = Input.Tex + float2(texelSize * -2.0f, 0.0f);
    Output.Tex4 = Input.Tex + float2(texelSize * -1.0f, 0.0f);
    Output.Tex5 = Input.Tex + float2(texelSize * 0.0f, 0.0f);
    Output.Tex6 = Input.Tex + float2(texelSize * 1.0f, 0.0f);
    Output.Tex7 = Input.Tex + float2(texelSize * 2.0f, 0.0f);
    Output.Tex8 = Input.Tex + float2(texelSize * 3.0f, 0.0f);
    Output.Tex9 = Input.Tex + float2(texelSize * 4.0f, 0.0f);
    
    return Output;
}

QuadVS_Output VertexVerticalBlur(QuadVS_Input Input)
{
    QuadVS_Output Output;
    float texelSize;
    
    Input.Pos.w = 1.0f;
    
    Output.Pos = mul(Input.Pos, World);
    Output.Pos = mul(Output.Pos, View);
    Output.Pos = mul(Input.Pos, Projection);
    Output.Tex = Input.Tex;
    
    texelSize = 1.0f / 720.0f;
    
    Output.Tex1 = Input.Tex + float2(0.0f, texelSize * -4.0f);
    Output.Tex2 = Input.Tex + float2(0.0f, texelSize * -3.0f);
    Output.Tex3 = Input.Tex + float2(0.0f, texelSize * -2.0f);
    Output.Tex4 = Input.Tex + float2(0.0f, texelSize * -1.0f);
    Output.Tex5 = Input.Tex + float2(0.0f, texelSize * 0.0f);
    Output.Tex6 = Input.Tex + float2(0.0f, texelSize * 1.0f);
    Output.Tex7 = Input.Tex + float2(0.0f, texelSize * 2.0f);
    Output.Tex8 = Input.Tex + float2(0.0f, texelSize * 3.0f);
    Output.Tex9 = Input.Tex + float2(0.0f, texelSize * 4.0f);
    
    return Output;
}
//--------------------------------------------------------------------------------------
// Pixel Shader
//--------------------------------------------------------------------------------------
float4 QuadPS(QuadVS_Output Input) : SV_TARGET
{
    float4 vColour = txDiffuse.Sample(samLinear, Input.Tex);
    
    float weight0, weight1, weight2, weight3, weight4;
    float normalization;
    float4 color;
    
    weight0 = 1.0f;
    weight1 = 0.9f;
    weight2 = 0.55f;
    weight3 = 0.18f;
    weight4 = 0.1f;
    
    normalization = (weight0 + 2.0f * (weight1 + weight2 + weight3 + weight4));
    
    weight0 = weight0 / normalization;
    weight1 = weight1 / normalization;
    weight2 = weight2 / normalization;
    weight3 = weight3 / normalization;
    weight4 = weight4 / normalization;
    
    color = float4(0.0f, 0.0f, 0.0f, 0.0f);
    
    color += txDiffuse.Sample(samLinear, Input.Tex1) * weight4;
    color += txDiffuse.Sample(samLinear, Input.Tex2) * weight3;
    color += txDiffuse.Sample(samLinear, Input.Tex3) * weight2;
    color += txDiffuse.Sample(samLinear, Input.Tex4) * weight1;
    color += txDiffuse.Sample(samLinear, Input.Tex5) * weight0;
    color += txDiffuse.Sample(samLinear, Input.Tex6) * weight1;
    color += txDiffuse.Sample(samLinear, Input.Tex7) * weight2;
    color += txDiffuse.Sample(samLinear, Input.Tex8) * weight3;
    color += txDiffuse.Sample(samLinear, Input.Tex9) * weight4;
    
    color.a = 1.0f;
    
    return color;
}

