#pragma once
#pragma comment (lib, "dinput8.lib")
#pragma comment (lib, "dxguid.lib")
#include <d3d11_1.h>
#include <d3dcompiler.h>
#include <directxmath.h>
#include "resource.h"
#include "structures.h"

class Camera
{
public:
	Camera(XMFLOAT3 position, XMFLOAT3 at, XMFLOAT3 up, FLOAT windowWidth, FLOAT windowHeight, FLOAT nearDepth, FLOAT farDepth);
	~Camera();

	void Update();

	//Return Position, Lookat and up;
	XMFLOAT3 GetPosition() { return _eye; }
	void SetPosition(XMFLOAT3 position) { _eye = position; }
	XMFLOAT3 GetLookAt() { return _at; }
	void SetLookAt(XMFLOAT3 atPosition) { _at = atPosition; }
	XMFLOAT3 GetUp() { return _up; }
	void SetUp(XMFLOAT3 upPosition) { _up = upPosition; }

	//Return View, Projection and combined viewProjection;
	XMFLOAT4X4* GetView() { return &_view; }
	void SetView()
	{
		XMVECTOR Eye = XMVectorSet(_eye.x, _eye.y, _eye.z, 0.0f);
		XMVECTOR At = XMVectorSet(_at.x, _at.y, _at.z, 0.0f);
		XMVECTOR Up = XMVectorSet(_up.x, _up.y, _up.z, 0.0f);

		XMStoreFloat4x4(&_view, XMMatrixLookAtLH(Eye, At, Up));
	}
	XMFLOAT4X4* GetProjection() { return &_projection; }
	void SetProjection()
	{
		XMStoreFloat4x4(&_projection, XMMatrixPerspectiveFovLH(XM_PIDIV2, _windowWidth / (FLOAT)_windowHeight, _nearDepth, _farDepth));
	}

	void Reshape(FLOAT windowWidth, FLOAT windowHeight, FLOAT nearDepth, FLOAT farDepth);

private:
	XMFLOAT3 _eye;
	XMFLOAT3 _at;
	XMFLOAT3 _up;

	FLOAT _windowWidth;
	FLOAT _windowHeight;
	FLOAT _nearDepth;
	FLOAT _farDepth;

	XMFLOAT4X4 _view;
	XMFLOAT4X4 _projection;
};

