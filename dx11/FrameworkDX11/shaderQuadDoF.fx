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
Texture2D txDepth : register(t1);

cbuffer BlurBufferHorizontal : register(b0)
{
    bool horizontal;
    float3 padding01;
};

cbuffer BlurBufferVertical : register(b1)
{
    bool vertical;
    float3 padding02;
};

SamplerState samLinear : register(s0);

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

float3 GuassianBlur(float2 texCoords)
{
    float weight[5] = { 0.227027, 0.1945946, 0.1216216, 0.054054, 0.016216 };
    
    float3 vColour = txDiffuse.Sample(samLinear, texCoords).rgb * weight[0];
    float2 textureOffset = 1 / txDiffuse.Sample(samLinear, 0);

    //textureOffset.y = 0.0;
    
    if (horizontal == true)
    {
        for (int i = 1; i < 5; i++)
        {
            vColour += txDiffuse.Sample(samLinear, texCoords + float2(textureOffset.y * i, 0.0)).rgb * weight[i];
            vColour += txDiffuse.Sample(samLinear, texCoords - float2(textureOffset.y * i, 0.0)).rgb * weight[i];
        }
    }
    if (vertical == true)
    {
        for (int i = 1; i < 5; i++)
        {
            vColour += txDiffuse.Sample(samLinear, texCoords + float2(0.0, textureOffset.y * i)).rgb * weight[i];
            vColour += txDiffuse.Sample(samLinear, texCoords - float2(0.0, textureOffset.y * i)).rgb * weight[i];
        }
    }
    
    return vColour;
}

float linearizeDepth(float depth)
{
    float z = (depth * 2.0) - 1.0;
   
    float yy = (2.0 * 1000.0) / (1001.0 - z * 999.0);
    depth = yy / 1000;
    return depth;

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
    float4 color = txDiffuse.Sample(samLinear, Input.Tex);
    float4 blur = float4(GuassianBlur(Input.Tex), 1.0);

    float depth = linearizeDepth(txDepth.Sample(samLinear, Input.Tex).r);
  
    blur += depth;
    color += blur;
    
    return color;
}
