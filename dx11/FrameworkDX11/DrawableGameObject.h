#pragma once

#include <d3d11_1.h>
#include <d3dcompiler.h>
#include <directxcolors.h>
#include <DirectXCollision.h>
#include "DDSTextureLoader.h"
#include "resource.h"
#include <iostream>
#include "structures.h"


using namespace DirectX;

struct SimpleVertex
{

	XMFLOAT3 Pos;
	XMFLOAT3 Normal;
	XMFLOAT2 TexCoord;
	XMFLOAT3 Tangent;
	XMFLOAT3 BiNormal; 
};

struct SimpleVertexQuad
{
	XMFLOAT3 Pos;
	XMFLOAT2 TexCoord;
};

class DrawableGameObject
{
public:
	DrawableGameObject();
	~DrawableGameObject();

	void cleanup();

	HRESULT								initMesh(ID3D11Device* pd3dDevice, ID3D11DeviceContext* pContext);
	void								update(float t, ID3D11DeviceContext* pContext);
	void								draw(ID3D11DeviceContext* pContext);
	ID3D11Buffer* getVertexBuffer() { return m_pVertexBuffer; }
	ID3D11Buffer** getVertexBuffer(bool quadTrue) { return &m_pVertexBuffer; }
	ID3D11Buffer* getIndexBuffer() { return m_pIndexBuffer; }
	ID3D11ShaderResourceView** getTextureResourceView() { return &m_pTextureResourceView; }
	XMFLOAT4X4* getTransform() { return &m_World; }
	ID3D11SamplerState** getTextureSamplerState() { return &m_pSamplerLinear; }
	ID3D11Buffer* getMaterialConstantBuffer() { return m_pMaterialConstantBuffer; }
	

	XMFLOAT3 getPosition() { return m_position; }

	float getPosition(float x, float y, float z) { return x = m_position.x, y = m_position.y, z = m_position.z; }
	void setPosition(XMFLOAT3 position);

	XMFLOAT3 getRotation() { return m_rotation; }
	float getRotation(float x, float y, float z) { return x = m_rotation.x, y = m_rotation.y, z = m_rotation.z; }

	XMFLOAT3							m_position;
	XMFLOAT3							m_rotation;

	bool isSpinning = false;

private:

	XMFLOAT4X4							m_World;

	ID3D11Buffer* m_pVertexBuffer;
	ID3D11Buffer* m_pIndexBuffer;
	ID3D11ShaderResourceView* m_pTextureResourceView;
	ID3D11ShaderResourceView* m_pNormalResourceView;
	ID3D11ShaderResourceView* m_pParraResourceView;
	ID3D11SamplerState* m_pSamplerLinear;
	MaterialPropertiesConstantBuffer	m_material;
	ID3D11Buffer* m_pMaterialConstantBuffer = nullptr;
};

