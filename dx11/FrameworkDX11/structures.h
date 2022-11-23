#pragma once
using namespace std;
using namespace DirectX;

//--------------------------------------------------------------------------------------
// Structures
//--------------------------------------------------------------------------------------

#define SAMPLE_COUNT 15

struct ConstantBuffer
{
	XMMATRIX mWorld;
	XMMATRIX mView;
	XMMATRIX mProjection;
	XMFLOAT4 vOutputColor;

	unsigned int defID;
	unsigned int renID;
	XMFLOAT2 padding01;
};

struct BlurBufferHorizontal
{
	BOOL horizontal; // 4 bytes HLSL, using bool uses 1 byte and so HLSL can't interpret it unless specified as BOOL
	XMFLOAT3 padding01; // 12 bytes 
};

struct BlurBufferVertical
{
	BOOL vertical; // 4 bytes HLSL, using bool uses 1 byte and so HLSL can't interpret it unless specified as BOOL
	XMFLOAT3 padding02; // 12 bytes 
};

struct MotionBlurBuffer
{
	XMMATRIX mWorld;
	XMMATRIX mView;
	XMMATRIX mProjection;
	XMMATRIX mInverseProjection;
	XMMATRIX mPreviousProjection;
	XMFLOAT4 vOutputColor;
};

struct _Material
{
	_Material()
		: Emissive(0.0f, 0.0f, 0.0f, 1.0f)
		, Ambient(0.1f, 0.1f, 0.1f, 1.0f)
		, Diffuse(1.0f, 1.0f, 1.0f, 1.0f)
		, Specular(1.0f, 1.0f, 1.0f, 1.0f)
		, SpecularPower(128.0f)
		, UseTexture(false)
	{}

	DirectX::XMFLOAT4   Emissive;
	//----------------------------------- (16 byte boundary)
	DirectX::XMFLOAT4   Ambient;
	//----------------------------------- (16 byte boundary)
	DirectX::XMFLOAT4   Diffuse;
	//----------------------------------- (16 byte boundary)
	DirectX::XMFLOAT4   Specular;
	//----------------------------------- (16 byte boundary)
	float               SpecularPower;
	// Add some padding complete the 16 byte boundary.
	int                 UseTexture;
	// Add some padding to complete the 16 byte boundary.
	float               Padding[2];
	//----------------------------------- (16 byte boundary)
}; // Total:                                80 bytes (5 * 16)

struct MaterialPropertiesConstantBuffer
{
	_Material   Material;
};

enum LightType
{
	DirectionalLight = 0,
	PointLight = 1,
	SpotLight = 2
};

#define MAX_LIGHTS 1

struct Light
{
	Light()
		: Position(0.0f, 0.0f, 0.0f, 1.0f)
		, Direction(0.0f, 0.0f, 1.0f, 0.0f)
		, Color(1.0f, 1.0f, 1.0f, 1.0f)
		, SpotAngle(DirectX::XM_PIDIV2)
		, ConstantAttenuation(1.0f)
		, LinearAttenuation(0.0f)
		, QuadraticAttenuation(0.0f)
		, LightType(DirectionalLight)
		, Enabled(0)
	{}

	Light(DirectX::XMFLOAT4 position , DirectX::XMFLOAT4 direction , DirectX::XMFLOAT4 colour ,
		 float spot_angle , float constant_attenuation , float linear_attenuation , 
		 float quadratic_attenuation , int light_type , int enabled)
		: Position(position.x , position.y , position.z , position.w)
		, Direction(direction.x, direction.y, direction.z, direction.w)
		, Color(colour.x, colour.y, colour.z, colour.z)
		, SpotAngle(spot_angle)
		, ConstantAttenuation(constant_attenuation)
		, LinearAttenuation(linear_attenuation)
		, QuadraticAttenuation(quadratic_attenuation)
		, LightType(light_type)
		, Enabled(enabled)
	{}
	DirectX::XMFLOAT4    Position;
	//----------------------------------- (16 byte boundary)
	DirectX::XMFLOAT4    Direction;
	//----------------------------------- (16 byte boundary)
	DirectX::XMFLOAT4    Color;
	//----------------------------------- (16 byte boundary)
	float       SpotAngle;
	float       ConstantAttenuation;
	float       LinearAttenuation;
	float       QuadraticAttenuation;
	//----------------------------------- (16 byte boundary)
	int         LightType;
	int         Enabled;
	// Add some padding to make this struct size a multiple of 16 bytes.
	int         Padding[2];
	//----------------------------------- (16 byte boundary)
};  // Total:                              80 bytes ( 5 * 16 )


struct LightPropertiesConstantBuffer
{
	LightPropertiesConstantBuffer()
		: EyePosition(0, 0, 0, 1)
		, GlobalAmbient(0.2f, 0.2f, 0.8f, 1.0f)
	{}

	DirectX::XMFLOAT4   EyePosition;
	//----------------------------------- (16 byte boundary)
	DirectX::XMFLOAT4   GlobalAmbient;
	//----------------------------------- (16 byte boundary)
	Light               Lights[MAX_LIGHTS]; // 80 * 8 bytes
};  // Total:                                  672 bytes (42 * 16)