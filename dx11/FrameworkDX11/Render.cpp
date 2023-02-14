#include "Render.h"

Render::Render(ID3D11Device* dxDevice, ID3D11DeviceContext* dxContent, ID3D11VertexShader* vertextShader, ID3D11PixelShader* pixelShader, ID3D11InputLayout* layout)
{
	pd3dDevice = dxDevice;
	pImmediateContext = dxContent;
	pVertexShader = vertextShader;
	pPixelShader = pixelShader;
	pLayout = layout;
}

Render::~Render()
{
	pd3dDevice = nullptr;
	pImmediateContext = nullptr;
	pVertexShader = nullptr;
	pPixelShader = nullptr;
	pVertexShader = nullptr;
	pLayout = nullptr;
}

void Render::DrawObjects(DrawableGameObject* gameobject, UINT stride, UINT offset, ID3D11Buffer* lightConstantBuffer, ID3D11Buffer* constantBuffer)
{
	pImmediateContext->IASetVertexBuffers(0, 1, gameobject->getVertexBuffer(true), &stride, &offset);
	pImmediateContext->IASetIndexBuffer(gameobject->getIndexBuffer(), DXGI_FORMAT_R16_UINT, 0);
	pImmediateContext->IASetInputLayout(pLayout);

	pImmediateContext->VSSetShader(pVertexShader, nullptr, 0);
	pImmediateContext->VSSetConstantBuffers(0, 1, &constantBuffer);
	pImmediateContext->VSSetConstantBuffers(2, 1, &lightConstantBuffer);

	//Pixel shader
	pImmediateContext->PSSetShader(pPixelShader, nullptr, 0);

	ID3D11Buffer* materialCB = gameobject->getMaterialConstantBuffer();
	pImmediateContext->PSSetConstantBuffers(1, 1, &materialCB);
	pImmediateContext->PSSetConstantBuffers(2, 1, &lightConstantBuffer);

	pImmediateContext->PSSetSamplers(0, 1, gameobject->getTextureSamplerState());

	pImmediateContext->PSSetShaderResources(0, 1, gameobject->getTextureResourceView());

	gameobject->draw(pImmediateContext);
}


void Render::DrawPlanes(Plane* gameobject, UINT stride, UINT offset, ID3D11Buffer* lightConstantBuffer, ID3D11Buffer* constantBuffer)
{
	pImmediateContext->IASetVertexBuffers(0, 1, gameobject->getVertexBuffer(true), &stride, &offset);
	pImmediateContext->IASetIndexBuffer(gameobject->getIndexBuffer(), DXGI_FORMAT_R16_UINT, 0);
	pImmediateContext->IASetInputLayout(pLayout);

	pImmediateContext->VSSetShader(pVertexShader, nullptr, 0);
	pImmediateContext->VSSetConstantBuffers(0, 1, &constantBuffer);
	pImmediateContext->VSSetConstantBuffers(2, 1, &lightConstantBuffer);

	//Pixel shader
	pImmediateContext->PSSetShader(pPixelShader, nullptr, 0);

	ID3D11Buffer* materialCB = gameobject->getMaterialConstantBuffer();
	pImmediateContext->PSSetConstantBuffers(1, 1, &materialCB);
	pImmediateContext->PSSetConstantBuffers(2, 1, &lightConstantBuffer);

	pImmediateContext->PSSetSamplers(0, 1, gameobject->getTextureSamplerState());

	pImmediateContext->PSSetShaderResources(0, 1, gameobject->getTextureResourceView());

	gameobject->draw(pImmediateContext);
}