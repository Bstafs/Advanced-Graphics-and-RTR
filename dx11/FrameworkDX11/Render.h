#pragma once
#include <d3d11_1.h>
#include "DrawableGameObject.h"
#include "Plane.h"
class Render
{
public:
	Render(ID3D11Device*  dxDevice,ID3D11DeviceContext* dxContent, ID3D11VertexShader* vertextShader, ID3D11PixelShader* pixelShader, ID3D11InputLayout* layout);
	~Render();
	void DrawObjects(DrawableGameObject * gameobject, UINT stride, UINT offset, ID3D11Buffer* lightConstantBuffer, ID3D11Buffer* constantBuffer);
	void DrawPlanes(Plane * gameobject, UINT stride, UINT offset, ID3D11Buffer* lightConstantBuffer, ID3D11Buffer* constantBuffer);
private:
	ID3D11Device* pd3dDevice = nullptr;
	ID3D11DeviceContext* pImmediateContext = nullptr;
	ID3D11VertexShader* pVertexShader = nullptr;
	ID3D11PixelShader* pPixelShader = nullptr;
	ID3D11InputLayout* pLayout = nullptr;
};

