#pragma once

#include <d3d11_1.h>
#include <d3dcompiler.h>
#include <directxmath.h>
#include "resource.h"
#include "structures.h"

class Camera
{
public:
	Camera(XMFLOAT4 position, XMFLOAT4 at, XMFLOAT4 up, FLOAT windowWidth, FLOAT windowHeight, FLOAT nearDepth, FLOAT farDepth);
	~Camera();

	void Update();

	//Return Position, Lookat and up;
	XMFLOAT4 GetPosition() { return _eye; }
	void SetPosition(XMFLOAT4 position) { _eye = position; }
	XMFLOAT4 GetLookAt() { return _at; }
	void SetLookAt(XMFLOAT4 atPosition) { _at = atPosition; }
	XMFLOAT4 GetUp() { return _up; }
	void SetUp(XMFLOAT4 upPosition) { _up = upPosition; }

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
	XMFLOAT4 _eye;
	XMFLOAT4 _at;
	XMFLOAT4 _up;

	FLOAT _windowWidth;
	FLOAT _windowHeight;
	FLOAT _nearDepth;
	FLOAT _farDepth;

	XMFLOAT4X4 _view;
	XMFLOAT4X4 _projection;
};

