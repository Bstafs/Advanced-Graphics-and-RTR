//--------------------------------------------------------------------------------------
// File: main.cpp
//
// This application demonstrates animation using matrix transformations
//
// http://msdn.microsoft.com/en-us/library/windows/apps/ff729722.aspx
//
// THIS CODE AND INFORMATION IS PROVIDED "AS IS" WITHOUT WARRANTY OF
// ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO
// THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A
// PARTICULAR PURPOSE.
//
// Copyright (c) Microsoft Corporation. All rights reserved.
//--------------------------------------------------------------------------------------
#define _XM_NO_INTRINSICS_

#include "Application.h"

DirectX::XMFLOAT4 g_EyePosition(0.0f, 0, -3, 1.0f);

//--------------------------------------------------------------------------------------
// Forward declarations
//--------------------------------------------------------------------------------------
HRESULT		InitWindow(HINSTANCE hInstance, int nCmdShow);
HRESULT		InitDevice();
HRESULT		InitMesh();
HRESULT		InitWorld(int width, int height, HWND hwnd);
void		CleanupDevice();
LRESULT CALLBACK    WndProc(HWND, UINT, WPARAM, LPARAM);
void		Render();
void RenderToTarget();
void UpdateCamera();
bool InitDirectInput(HINSTANCE hInstance);
void DetectInput(double deltaTime);
void IMGUI();

//--------------------------------------------------------------------------------------
// Global Variables
//--------------------------------------------------------------------------------------
HINSTANCE               g_hInst = nullptr;
HWND                    g_hWnd = nullptr;
D3D_DRIVER_TYPE         g_driverType = D3D_DRIVER_TYPE_NULL;
D3D_FEATURE_LEVEL       g_featureLevel = D3D_FEATURE_LEVEL_11_0;
ID3D11Device* g_pd3dDevice = nullptr;
ID3D11Device1* g_pd3dDevice1 = nullptr;
ID3D11DeviceContext* g_pImmediateContext = nullptr;
ID3D11DeviceContext1* g_pImmediateContext1 = nullptr;
IDXGISwapChain* g_pSwapChain = nullptr;
IDXGISwapChain1* g_pSwapChain1 = nullptr;
ID3D11RenderTargetView* g_pRenderTargetView = nullptr;
ID3D11Texture2D* g_pDepthStencil = nullptr;
ID3D11DepthStencilView* g_pDepthStencilView = nullptr;
ID3D11VertexShader* g_pVertexShader = nullptr;

ID3D11PixelShader* g_pPixelShader = nullptr;

ID3D11InputLayout* g_pVertexLayout = nullptr;

ID3D11Buffer* g_pConstantBuffer = nullptr;

ID3D11Buffer* g_pLightConstantBuffer = nullptr;

D3D11_TEXTURE2D_DESC textureDesc;
D3D11_RENDER_TARGET_VIEW_DESC renderTargetViewDesc;
D3D11_SHADER_RESOURCE_VIEW_DESC shaderResourceViewDesc;

ID3D11Texture2D* g_pRTTRrenderTargetTexture = nullptr;
ID3D11RenderTargetView* g_pRTTRenderTargetView = nullptr;
ID3D11ShaderResourceView* g_pRTTShaderResourceView = nullptr;

struct SCREEN_VERTEX
{
	XMFLOAT3 pos;
	XMFLOAT2 tex;
};

ID3D11ShaderResourceView* g_pQuadShaderResourceView = nullptr;
ID3D11Buffer* g_pQuadVB = nullptr;
ID3D11Buffer* g_pQuadIB = nullptr;

ID3D11InputLayout* g_pQuadLayout = nullptr;
ID3D11VertexShader* g_pQuadVS = nullptr;
ID3D11PixelShader* g_pQuadPS = nullptr;
SCREEN_VERTEX svQuad[4];

ID3D11Buffer* g_pVertexBuffer = nullptr;
ID3D11Buffer* g_pIndexBuffer = nullptr;

Light					g_Lighting;
XMMATRIX                g_View;
XMMATRIX                g_Projection;

int						g_viewWidth;
int						g_viewHeight;

DrawableGameObject		g_GameObject;

//Camera
Camera* g_pCamera0;
Camera* g_pCurrentCamera;

float currentPosZ = -3.0f;
float currentPosX = 0.0f;
float currentPosY = 0.0f;
float rotationX = 0.0f;
float rotationY = 0.0f;

#include <dinput.h>

IDirectInputDevice8* DIMouse;
DIMOUSESTATE mouseLastState;
LPDIRECTINPUT8 DirectInput;

HRESULT hr;

XMFLOAT4 LightPosition(g_EyePosition);

//--------------------------------------------------------------------------------------d
// Entry point to the program. Initializes everything and goes into a message processing 
// loop. Idle time is used to render the scene.
//--------------------------------------------------------------------------------------
int WINAPI wWinMain(_In_ HINSTANCE hInstance, _In_opt_ HINSTANCE hPrevInstance, _In_ LPWSTR lpCmdLine, _In_ int nCmdShow)
{
	UNREFERENCED_PARAMETER(hPrevInstance);
	UNREFERENCED_PARAMETER(lpCmdLine);

	if (FAILED(InitWindow(hInstance, nCmdShow)))
		return 0;

	if (FAILED(InitDevice()))
	{
		CleanupDevice();
		return 0;
	}

	if (!InitDirectInput(hInstance))
	{
		MessageBox(0, L"Direct Input Initialization - Failed",
			L"Error", MB_OK);
		return 0;
	}

	// Main message loop
	MSG msg = { 0 };
	while (WM_QUIT != msg.message)
	{
		if (PeekMessage(&msg, nullptr, 0, 0, PM_REMOVE))
		{
			TranslateMessage(&msg);
			DispatchMessage(&msg);
		}
		else
		{
			//Render();
			RenderToTarget();
			UpdateCamera();
		}
	}

	CleanupDevice();

	return (int)msg.wParam;
}


//--------------------------------------------------------------------------------------
// Register class and create window
//--------------------------------------------------------------------------------------
HRESULT InitWindow(HINSTANCE hInstance, int nCmdShow)
{
	// Register class
	WNDCLASSEX wcex;
	wcex.cbSize = sizeof(WNDCLASSEX);
	wcex.style = CS_HREDRAW | CS_VREDRAW;
	wcex.lpfnWndProc = WndProc;
	wcex.cbClsExtra = 0;
	wcex.cbWndExtra = 0;
	wcex.hInstance = hInstance;
	wcex.hIcon = LoadIcon(hInstance, (LPCTSTR)IDI_TUTORIAL1);
	wcex.hCursor = LoadCursor(nullptr, IDC_ARROW);
	wcex.hbrBackground = (HBRUSH)(COLOR_WINDOW + 1);
	wcex.lpszMenuName = nullptr;
	wcex.lpszClassName = L"TutorialWindowClass";
	wcex.hIconSm = LoadIcon(wcex.hInstance, (LPCTSTR)IDI_TUTORIAL1);
	if (!RegisterClassEx(&wcex))
		return E_FAIL;

	// Create window
	g_hInst = hInstance;
	RECT rc = { 0, 0, 1280, 720 };

	g_viewWidth = 1280;
	g_viewHeight = 720;

	AdjustWindowRect(&rc, WS_OVERLAPPEDWINDOW, TRUE);
	g_hWnd = CreateWindow(L"TutorialWindowClass", L"Direct3D 11 Tutorial 5",
		WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_MINIMIZEBOX,
		CW_USEDEFAULT, CW_USEDEFAULT, rc.right - rc.left, rc.bottom - rc.top, nullptr, nullptr, hInstance,
		nullptr);
	if (!g_hWnd)
		return E_FAIL;

	ShowWindow(g_hWnd, nCmdShow);

	return S_OK;
}


//--------------------------------------------------------------------------------------
// Helper for compiling shaders with D3DCompile
//
// With VS 11, we could load up prebuilt .cso files instead...
//--------------------------------------------------------------------------------------
HRESULT CompileShaderFromFile(const WCHAR* szFileName, LPCSTR szEntryPoint, LPCSTR szShaderModel, ID3DBlob** ppBlobOut)
{
	HRESULT hr = S_OK;

	DWORD dwShaderFlags = D3DCOMPILE_ENABLE_STRICTNESS;
#ifdef _DEBUG
	// Set the D3DCOMPILE_DEBUG flag to embed debug information in the shaders.
	// Setting this flag improves the shader debugging experience, but still allows 
	// the shaders to be optimized and to run exactly the way they will run in 
	// the release configuration of this program.
	dwShaderFlags |= D3DCOMPILE_DEBUG;

	// Disable optimizations to further improve shader debugging
	dwShaderFlags |= D3DCOMPILE_SKIP_OPTIMIZATION;
#endif

	ID3DBlob* pErrorBlob = nullptr;
	hr = D3DCompileFromFile(szFileName, nullptr, nullptr, szEntryPoint, szShaderModel,
		dwShaderFlags, 0, ppBlobOut, &pErrorBlob);
	if (FAILED(hr))
	{
		if (pErrorBlob)
		{
			OutputDebugStringA(reinterpret_cast<const char*>(pErrorBlob->GetBufferPointer()));
			pErrorBlob->Release();
		}
		return hr;
	}
	if (pErrorBlob) pErrorBlob->Release();

	return S_OK;
}


//--------------------------------------------------------------------------------------
// Create Direct3D device and swap chain
//--------------------------------------------------------------------------------------
HRESULT InitDevice()
{
	HRESULT hr = S_OK;

	RECT rc;
	GetClientRect(g_hWnd, &rc);
	UINT width = rc.right - rc.left;
	UINT height = rc.bottom - rc.top;

	UINT createDeviceFlags = 0;
#ifdef _DEBUG
	createDeviceFlags |= D3D11_CREATE_DEVICE_DEBUG;
#endif

	D3D_DRIVER_TYPE driverTypes[] =
	{
		D3D_DRIVER_TYPE_HARDWARE,
		D3D_DRIVER_TYPE_WARP,
		D3D_DRIVER_TYPE_REFERENCE,
	};
	UINT numDriverTypes = ARRAYSIZE(driverTypes);

	D3D_FEATURE_LEVEL featureLevels[] =
	{
		D3D_FEATURE_LEVEL_11_1,
		D3D_FEATURE_LEVEL_11_0,
		D3D_FEATURE_LEVEL_10_1,
		D3D_FEATURE_LEVEL_10_0,
	};
	UINT numFeatureLevels = ARRAYSIZE(featureLevels);

	for (UINT driverTypeIndex = 0; driverTypeIndex < numDriverTypes; driverTypeIndex++)
	{
		g_driverType = driverTypes[driverTypeIndex];
		hr = D3D11CreateDevice(nullptr, g_driverType, nullptr, createDeviceFlags, featureLevels, numFeatureLevels,
			D3D11_SDK_VERSION, &g_pd3dDevice, &g_featureLevel, &g_pImmediateContext);

		if (hr == E_INVALIDARG)
		{
			// DirectX 11.0 platforms will not recognize D3D_FEATURE_LEVEL_11_1 so we need to retry without it
			hr = D3D11CreateDevice(nullptr, g_driverType, nullptr, createDeviceFlags, &featureLevels[1], numFeatureLevels - 1,
				D3D11_SDK_VERSION, &g_pd3dDevice, &g_featureLevel, &g_pImmediateContext);
		}

		if (SUCCEEDED(hr))
			break;
	}
	if (FAILED(hr))
		return hr;

	// Obtain DXGI factory from device (since we used nullptr for pAdapter above)
	IDXGIFactory1* dxgiFactory = nullptr;
	{
		IDXGIDevice* dxgiDevice = nullptr;
		hr = g_pd3dDevice->QueryInterface(__uuidof(IDXGIDevice), reinterpret_cast<void**>(&dxgiDevice));
		if (SUCCEEDED(hr))
		{
			IDXGIAdapter* adapter = nullptr;
			hr = dxgiDevice->GetAdapter(&adapter);
			if (SUCCEEDED(hr))
			{
				hr = adapter->GetParent(__uuidof(IDXGIFactory1), reinterpret_cast<void**>(&dxgiFactory));
				adapter->Release();
			}
			dxgiDevice->Release();
		}
	}
	if (FAILED(hr))
		return hr;

	// Create swap chain
	//IDXGIFactory2* dxgiFactory2 = nullptr;
	//hr = dxgiFactory->QueryInterface(__uuidof(IDXGIFactory2), reinterpret_cast<void**>(&dxgiFactory2));
	//if (dxgiFactory2)
	//{
	//	// DirectX 11.1 or later
	//	hr = g_pd3dDevice->QueryInterface(__uuidof(ID3D11Device1), reinterpret_cast<void**>(&g_pd3dDevice1));
	//	if (SUCCEEDED(hr))
	//	{
	//		(void)g_pImmediateContext->QueryInterface(__uuidof(ID3D11DeviceContext1), reinterpret_cast<void**>(&g_pImmediateContext1));
	//	}

	//	DXGI_SWAP_CHAIN_DESC1 sd = {};
	//	sd.Width = width;
	//	sd.Height = height;
	//	sd.Format = DXGI_FORMAT_R16G16B16A16_FLOAT;//  DXGI_FORMAT_R16G16B16A16_FLOAT;////DXGI_FORMAT_R8G8B8A8_UNORM;
	//	sd.SampleDesc.Count = 1;
	//	sd.SampleDesc.Quality = 0;
	//	sd.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
	//	sd.BufferCount = 1;

	//	hr = dxgiFactory2->CreateSwapChainForHwnd(g_pd3dDevice, g_hWnd, &sd, nullptr, nullptr, &g_pSwapChain1);
	//	if (SUCCEEDED(hr))
	//	{
	//		hr = g_pSwapChain1->QueryInterface(__uuidof(IDXGISwapChain), reinterpret_cast<void**>(&g_pSwapChain));
	//	}

	//	dxgiFactory2->Release();
	//}
	//else
	//{
	//	// DirectX 11.0 systems
	//	DXGI_SWAP_CHAIN_DESC sd = {};
	//	sd.BufferCount = 1;
	//	sd.BufferDesc.Width = width;
	//	sd.BufferDesc.Height = height;
	//	sd.BufferDesc.Format = DXGI_FORMAT_R8G8B8A8_UNORM;
	//	sd.BufferDesc.RefreshRate.Numerator = 60;
	//	sd.BufferDesc.RefreshRate.Denominator = 1;
	//	sd.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
	//	sd.OutputWindow = g_hWnd;
	//	sd.SampleDesc.Count = 1;
	//	sd.SampleDesc.Quality = 0;
	//	sd.Windowed = FALSE;

	//	hr = dxgiFactory->CreateSwapChain(g_pd3dDevice, &sd, &g_pSwapChain);
	//}

	//// Note this tutorial doesn't handle full-screen swapchains so we block the ALT+ENTER shortcut
	//dxgiFactory->MakeWindowAssociation(g_hWnd, DXGI_MWA_NO_ALT_ENTER);

	//dxgiFactory->Release();

 //  if (FAILED(hr))
	//	return hr;

	//// Create SwapChain
	UINT maxQuality = 0;
	UINT sampleCount = 4;
	DXGI_SWAP_CHAIN_DESC sd = {};
	sd.BufferCount = 1;
	sd.BufferDesc.Width = width;
	sd.BufferDesc.Height = height;
	sd.BufferDesc.Format = DXGI_FORMAT_R16G16B16A16_FLOAT;// DXGI_FORMAT_R16G16B16A16_FLOAT;//  DXGI_FORMAT_R16G16B16A16_FLOAT;////DXGI_FORMAT_R8G8B8A8_UNORM;
	sd.BufferDesc.RefreshRate.Numerator = 60;
	sd.BufferDesc.RefreshRate.Denominator = 1;
	sd.SampleDesc.Count = sampleCount;
	sd.SampleDesc.Quality = maxQuality;
	sd.OutputWindow = g_hWnd;
	sd.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
	sd.Windowed = TRUE;

	hr = g_pd3dDevice->CheckMultisampleQualityLevels(sd.BufferDesc.Format, sd.SampleDesc.Count, &maxQuality);

	maxQuality -= 1;
	sd.SampleDesc.Quality = maxQuality;
	hr = dxgiFactory->CreateSwapChain(g_pd3dDevice, &sd, &g_pSwapChain);

	// Note this tutorial doesn't handle full-screen swapchains so we block the ALT+ENTER shortcut
	dxgiFactory->MakeWindowAssociation(g_hWnd, DXGI_MWA_NO_ALT_ENTER);

	dxgiFactory->Release();

	if (FAILED(hr))
		return hr;

	// Create a render target view
	ID3D11Texture2D* pBackBuffer = nullptr;
	hr = g_pSwapChain->GetBuffer(0, __uuidof(ID3D11Texture2D), reinterpret_cast<void**>(&pBackBuffer));
	if (FAILED(hr))
		return hr;

	hr = g_pd3dDevice->CreateRenderTargetView(pBackBuffer, nullptr, &g_pRenderTargetView);
	pBackBuffer->Release();
	if (FAILED(hr))
		return hr;

	// Create depth stencil texture
	D3D11_TEXTURE2D_DESC descDepth = {};
	descDepth.Width = width;
	descDepth.Height = height;
	descDepth.MipLevels = 1;
	descDepth.ArraySize = 1;
	descDepth.Format = DXGI_FORMAT_D24_UNORM_S8_UINT;
	descDepth.SampleDesc.Count = sampleCount;
	descDepth.SampleDesc.Quality = maxQuality;
	descDepth.Usage = D3D11_USAGE_DEFAULT;
	descDepth.BindFlags = D3D11_BIND_DEPTH_STENCIL;
	descDepth.CPUAccessFlags = 0;
	descDepth.MiscFlags = 0;
	hr = g_pd3dDevice->CreateTexture2D(&descDepth, nullptr, &g_pDepthStencil);
	if (FAILED(hr))
		return hr;

	//Texture Render
	D3D11_TEXTURE2D_DESC textureDesc;
	ZeroMemory(&textureDesc, sizeof(textureDesc));

	textureDesc.Width = width;
	textureDesc.Height = height;
	textureDesc.MipLevels = 1;
	textureDesc.ArraySize = 1;
	textureDesc.Format = DXGI_FORMAT_R32G32B32A32_FLOAT;
	textureDesc.SampleDesc.Count = sampleCount;
	textureDesc.Usage = D3D11_USAGE_DEFAULT;
	textureDesc.BindFlags = D3D11_BIND_RENDER_TARGET | D3D11_BIND_SHADER_RESOURCE;
	textureDesc.CPUAccessFlags = 0;
	textureDesc.MiscFlags = 0;
	hr = g_pd3dDevice->CreateTexture2D(&textureDesc, nullptr, &g_pRTTRrenderTargetTexture);

	renderTargetViewDesc.Format = textureDesc.Format;
	renderTargetViewDesc.ViewDimension = D3D11_RTV_DIMENSION_TEXTURE2DMS;
	renderTargetViewDesc.Texture2D.MipSlice = 0;

	// Create the render target view.
	hr = g_pd3dDevice->CreateRenderTargetView(g_pRTTRrenderTargetTexture, &renderTargetViewDesc, &g_pRTTRenderTargetView);
	if (FAILED(hr))
		return hr;

	shaderResourceViewDesc.Format = textureDesc.Format;
	shaderResourceViewDesc.ViewDimension = D3D11_SRV_DIMENSION_TEXTURE2DMS;
	shaderResourceViewDesc.Texture2D.MostDetailedMip = 0;
	shaderResourceViewDesc.Texture2D.MipLevels = 1;

	// Create the shader resource view.
	hr = g_pd3dDevice->CreateShaderResourceView(g_pRTTRrenderTargetTexture, &shaderResourceViewDesc, &g_pRTTShaderResourceView);
	g_pRTTRrenderTargetTexture->Release();
	if (FAILED(hr))
		return hr;

	// QUAD

// Vertices
	SimpleVertexQuad v[] =
	{

	{ XMFLOAT3(-1.0f, -1.0f, 0.0f), XMFLOAT2(0.0f, 1.0f) },

	{ XMFLOAT3(-1.0f, 1.0f, 0.0f), XMFLOAT2(0.0f, 0.0f) },

	{ XMFLOAT3(1.0f, 1.0f, 0.0f), XMFLOAT2(1.0f, 0.0f) },

	{ XMFLOAT3(1.0f, -1.0f, 0.0f), XMFLOAT2(1.0f, 1.0f) },

	};

	// generate vb
	D3D11_BUFFER_DESC bd = {};
	bd.Usage = D3D11_USAGE_DEFAULT;
	bd.ByteWidth = sizeof(SimpleVertexQuad) * 6;
	bd.BindFlags = D3D11_BIND_VERTEX_BUFFER;
	bd.CPUAccessFlags = 0;

	D3D11_SUBRESOURCE_DATA InitData = {};
	InitData.pSysMem = v;
	 hr = g_pd3dDevice->CreateBuffer(&bd, &InitData, &g_pQuadVB);
	if (FAILED(hr))
		return hr;

	// Create index buffer
	WORD indices[] =
	{
      0,1,2,
      0,2,3,
	};

	bd.Usage = D3D11_USAGE_DEFAULT;
	bd.ByteWidth = sizeof(WORD) * 6;        // 36 vertices needed for 12 triangles in a triangle list
	bd.BindFlags = D3D11_BIND_INDEX_BUFFER;
	bd.CPUAccessFlags = 0;
	InitData.pSysMem = indices;
	hr = g_pd3dDevice->CreateBuffer(&bd, &InitData, &g_pQuadIB);
	if (FAILED(hr))
		return hr;

	g_pImmediateContext->IASetPrimitiveTopology(D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST);

	// Create the depth stencil view
	D3D11_DEPTH_STENCIL_VIEW_DESC descDSV = {};
	descDSV.Format = descDepth.Format;
	descDSV.ViewDimension = D3D11_DSV_DIMENSION_TEXTURE2DMS;
	descDSV.Texture2D.MipSlice = 0;
	hr = g_pd3dDevice->CreateDepthStencilView(g_pDepthStencil, &descDSV, &g_pDepthStencilView);
	if (FAILED(hr))
		return hr;

	g_pImmediateContext->OMSetRenderTargets(1, &g_pRenderTargetView, g_pDepthStencilView);


	// Setup the viewport
	D3D11_VIEWPORT vp;
	vp.Width = (FLOAT)width;
	vp.Height = (FLOAT)height;
	vp.MinDepth = 0.0f;
	vp.MaxDepth = 1.0f;
	vp.TopLeftX = 0;
	vp.TopLeftY = 0;
	g_pImmediateContext->RSSetViewports(1, &vp);

	hr = InitMesh();
	if (FAILED(hr))
	{
		MessageBox(nullptr,
			L"Failed to initialise mesh.", L"Error", MB_OK);
		return hr;
	}

	hr = InitWorld(width, height, g_hWnd);
	if (FAILED(hr))
	{
		MessageBox(nullptr,
			L"Failed to initialise world.", L"Error", MB_OK);
		return hr;
	}

	hr = g_GameObject.initMesh(g_pd3dDevice, g_pImmediateContext);
	if (FAILED(hr))
		return hr;

	return S_OK;
}

// ***************************************************************************************
// InitMesh
// ***************************************************************************************

HRESULT		InitMesh()
{
	// Compile the vertex shader
	ID3DBlob* pVSBlob = nullptr;
	HRESULT hr = CompileShaderFromFile(L"shader.fx", "VS", "vs_4_0", &pVSBlob);
	if (FAILED(hr))
	{
		MessageBox(nullptr,
			L"The FX file cannot be compiled.  Please run this executable from the directory that contains the FX file.", L"Error", MB_OK);
		return hr;
	}

	// Create the vertex shader
	hr = g_pd3dDevice->CreateVertexShader(pVSBlob->GetBufferPointer(), pVSBlob->GetBufferSize(), nullptr, &g_pVertexShader);
	if (FAILED(hr))
	{
		pVSBlob->Release();
		return hr;
	}

	// Layout
		// Define the input layout
	D3D11_INPUT_ELEMENT_DESC layout[] =
	{
		{ "POSITION", 0, DXGI_FORMAT_R32G32B32_FLOAT, 0, D3D11_APPEND_ALIGNED_ELEMENT , D3D11_INPUT_PER_VERTEX_DATA, 0 },
		{ "NORMAL", 0, DXGI_FORMAT_R32G32B32_FLOAT, 0, D3D11_APPEND_ALIGNED_ELEMENT , D3D11_INPUT_PER_VERTEX_DATA, 0 },
		{ "TEXCOORD", 0, DXGI_FORMAT_R32G32_FLOAT, 0, D3D11_APPEND_ALIGNED_ELEMENT, D3D11_INPUT_PER_VERTEX_DATA, 0 },
		{ "TANGENT", 0, DXGI_FORMAT_R32G32B32_FLOAT, 0, D3D11_APPEND_ALIGNED_ELEMENT, D3D11_INPUT_PER_VERTEX_DATA, 0 },
		{ "BINORMAL", 0, DXGI_FORMAT_R32G32B32_FLOAT, 0, D3D11_APPEND_ALIGNED_ELEMENT, D3D11_INPUT_PER_VERTEX_DATA, 0 },
	};
	UINT numElements = ARRAYSIZE(layout);

	// Create the input layout
	hr = g_pd3dDevice->CreateInputLayout(layout, numElements, pVSBlob->GetBufferPointer(),
		pVSBlob->GetBufferSize(), &g_pVertexLayout);
	pVSBlob->Release();
	if (FAILED(hr))
		return hr;


	// Compile the vertex shader
	pVSBlob = nullptr;
	hr = CompileShaderFromFile(L"shaderQuad.fx", "QuadVS", "vs_4_0", &pVSBlob);
	if (FAILED(hr))
	{
		MessageBox(nullptr,
			L"The FX file cannot be compiled.  Please run this executable from the directory that contains the FX file.", L"Error", MB_OK);
		return hr;
	}

	// Create the vertex shader
	hr = g_pd3dDevice->CreateVertexShader(pVSBlob->GetBufferPointer(), pVSBlob->GetBufferSize(), nullptr, &g_pQuadVS);
	if (FAILED(hr))
	{
		pVSBlob->Release();
		return hr;
	}

	// Define the input layout
	D3D11_INPUT_ELEMENT_DESC layoutQuad[] =
	{
		{ "POSITION", 0, DXGI_FORMAT_R32G32B32_FLOAT, 0, D3D11_APPEND_ALIGNED_ELEMENT , D3D11_INPUT_PER_VERTEX_DATA, 0 },
		{ "TEXCOORD", 0, DXGI_FORMAT_R32G32_FLOAT, 0, D3D11_APPEND_ALIGNED_ELEMENT, D3D11_INPUT_PER_VERTEX_DATA, 0 },
	};
	numElements = ARRAYSIZE(layoutQuad);

	// Create the input layout
	hr = g_pd3dDevice->CreateInputLayout(layoutQuad, numElements, pVSBlob->GetBufferPointer(),
		pVSBlob->GetBufferSize(), &g_pQuadLayout);
	pVSBlob->Release();
	if (FAILED(hr))
		return hr;

	// Compile the pixel shader
	ID3DBlob* pPSBlob = nullptr;
	hr = CompileShaderFromFile(L"shader.fx", "PS", "ps_4_0", &pPSBlob);
	if (FAILED(hr))
	{
		MessageBox(nullptr,
			L"The FX file cannot be compiled.  Please run this executable from the directory that contains the FX file.", L"Error", MB_OK);
		return hr;
	}

	// Create the pixel shader
	hr = g_pd3dDevice->CreatePixelShader(pPSBlob->GetBufferPointer(), pPSBlob->GetBufferSize(), nullptr, &g_pPixelShader);
	pPSBlob->Release();
	if (FAILED(hr))
		return hr;


	// Compile the pixel shader
	pPSBlob = nullptr;
	hr = CompileShaderFromFile(L"shaderQuad.fx", "QuadPS", "ps_4_0", &pPSBlob);
	if (FAILED(hr))
	{
		MessageBox(nullptr,
			L"The FX file cannot be compiled.  Please run this executable from the directory that contains the FX file.", L"Error", MB_OK);
		return hr;
	}

	// Create the pixel shader
	hr = g_pd3dDevice->CreatePixelShader(pPSBlob->GetBufferPointer(), pPSBlob->GetBufferSize(), nullptr, &g_pQuadPS);
	pPSBlob->Release();
	if (FAILED(hr))
		return hr;

	// Create the constant buffer
	D3D11_BUFFER_DESC bd = {};
	bd.Usage = D3D11_USAGE_DEFAULT;
	bd.ByteWidth = sizeof(SimpleVertex) * 36;
	bd.BindFlags = D3D11_BIND_VERTEX_BUFFER;
	bd.CPUAccessFlags = 0;
	bd.Usage = D3D11_USAGE_DEFAULT;
	bd.ByteWidth = sizeof(WORD) * 36;        // 36 vertices needed for 12 triangles in a triangle list
	bd.BindFlags = D3D11_BIND_INDEX_BUFFER;
	bd.CPUAccessFlags = 0;
	bd.Usage = D3D11_USAGE_DEFAULT;
	bd.ByteWidth = sizeof(ConstantBuffer);
	bd.BindFlags = D3D11_BIND_CONSTANT_BUFFER;
	bd.CPUAccessFlags = 0;
	hr = g_pd3dDevice->CreateBuffer(&bd, nullptr, &g_pConstantBuffer);
	if (FAILED(hr))
		return hr;

	// Create the light constant buffer
	bd.Usage = D3D11_USAGE_DEFAULT;
	bd.ByteWidth = sizeof(LightPropertiesConstantBuffer);
	bd.BindFlags = D3D11_BIND_CONSTANT_BUFFER;
	bd.CPUAccessFlags = 0;
	hr = g_pd3dDevice->CreateBuffer(&bd, nullptr, &g_pLightConstantBuffer);
	if (FAILED(hr))
		return hr;


	return hr;
}

// ***************************************************************************************
// InitWorld (Initialize)
// ***************************************************************************************
HRESULT		InitWorld(int width, int height, HWND hwnd)
{
	// Initialize the view matrix
	//XMVECTOR Eye = XMLoadFloat4(&g_EyePosition);
	//XMVECTOR At = XMVectorSet(0.0f, 0.0f, 0.0f, 0.0f);
	//XMVECTOR Up = XMVectorSet(0.0f, 1.0f, 0.0f, 0.0f);
	//g_View = XMMatrixLookAtLH(Eye, At, Up);

	//// Initialize the projection matrix
	//g_Projection = XMMatrixPerspectiveFovLH(XM_PIDIV2, width / (FLOAT)height, 0.01f, 100.0f);

	IMGUI_CHECKVERSION();
	ImGui::CreateContext();
	ImGuiIO& io = ImGui::GetIO();
	ImGui_ImplWin32_Init(g_hWnd);
	ImGui_ImplDX11_Init(g_pd3dDevice, g_pImmediateContext);
	ImGui::StyleColorsClassic();

	g_Lighting.Position.x = 0.0f;
	g_Lighting.Position.y = 0.0f;
	g_Lighting.Position.z = -3.0f;

	g_pCamera0 = new Camera(XMFLOAT3(0.0f, 0.0f, -2.0f), XMFLOAT3(0.0f, 0.0f, 0.0f), XMFLOAT3(0.0f, 1.0f, 0.0f), g_viewWidth, g_viewHeight, 0.01f, 10.0f);
	g_pCurrentCamera = g_pCamera0;
	g_pCurrentCamera->SetView();
	g_pCurrentCamera->SetProjection();

	XMVECTOR LightDirection = XMVectorSet(0.0f, 0.0f, -1.0f, 0.0f);
	LightDirection = XMVector3Normalize(LightDirection);
	XMStoreFloat4(&g_Lighting.Direction, LightDirection);

	return S_OK;
}


//--------------------------------------------------------------------------------------
// Clean up the objects we've created
//--------------------------------------------------------------------------------------
void CleanupDevice()
{
	g_GameObject.cleanup();

	// Remove any bound render target or depth/stencil buffer
	ID3D11RenderTargetView* nullViews[] = { nullptr };
	g_pImmediateContext->OMSetRenderTargets(_countof(nullViews), nullViews, nullptr);

	if (g_pImmediateContext) g_pImmediateContext->ClearState();
	// Flush the immediate context to force cleanup
	if (g_pImmediateContext1) g_pImmediateContext1->Flush();
	g_pImmediateContext->Flush();

	DIMouse->Unacquire();
	DirectInput->Release();

	if (g_pLightConstantBuffer)	g_pLightConstantBuffer->Release();
	if (g_pVertexLayout) g_pVertexLayout->Release();
	if (g_pConstantBuffer) g_pConstantBuffer->Release();
	if (g_pVertexShader) g_pVertexShader->Release();
	if (g_pPixelShader) g_pPixelShader->Release();
	if (g_pDepthStencil) g_pDepthStencil->Release();
	if (g_pDepthStencilView) g_pDepthStencilView->Release();
	if (g_pRenderTargetView) g_pRenderTargetView->Release();
	if (g_pSwapChain1) g_pSwapChain1->Release();
	if (g_pSwapChain) g_pSwapChain->Release();
	if (g_pImmediateContext1) g_pImmediateContext1->Release();
	if (g_pImmediateContext) g_pImmediateContext->Release();

	ID3D11Debug* debugDevice = nullptr;
	g_pd3dDevice->QueryInterface(__uuidof(ID3D11Debug), reinterpret_cast<void**>(&debugDevice));

	if (g_pd3dDevice1) g_pd3dDevice1->Release();
	if (g_pd3dDevice) g_pd3dDevice->Release();

	// handy for finding dx memory leaks
	debugDevice->ReportLiveDeviceObjects(D3D11_RLDO_DETAIL);

	if (debugDevice)
		debugDevice->Release();
}


//--------------------------------------------------------------------------------------
// Called every time the application receives a message
//--------------------------------------------------------------------------------------

extern LRESULT ImGui_ImplWin32_WndProcHandler(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam);

LRESULT CALLBACK WndProc(HWND hWnd, UINT message, WPARAM wParam, LPARAM lParam)
{
	if (ImGui_ImplWin32_WndProcHandler(hWnd, message, wParam, lParam))
	{
		return true;
	}

	PAINTSTRUCT ps;
	HDC hdc;

	switch (message)
	{
	case WM_LBUTTONDOWN:
	{
		int xPos = GET_X_LPARAM(lParam);
		int yPos = GET_Y_LPARAM(lParam);
		break;
	}
	case WM_PAINT:
		hdc = BeginPaint(hWnd, &ps);
		EndPaint(hWnd, &ps);
		break;

	case WM_DESTROY:
		PostQuitMessage(0);
		break;

		// Note that this tutorial does not handle resizing (WM_SIZE) requests,
		// so we created the window without the resize border.

	default:
		return DefWindowProc(hWnd, message, wParam, lParam);
	}

	return 0;
}

void setupLightForRender()
{
	g_Lighting.Enabled = static_cast<int>(true);
	g_Lighting.LightType = DirectionalLight;
	g_Lighting.Color = XMFLOAT4(Colors::White);
	g_Lighting.SpotAngle = XMConvertToRadians(45.0f);
	g_Lighting.ConstantAttenuation = 1.0f;
	g_Lighting.LinearAttenuation = 1;
	g_Lighting.QuadraticAttenuation = 1;

	XMFLOAT3 temp = g_pCurrentCamera->GetPosition();

	XMFLOAT4 temp4 = { temp.x, temp.y, temp.z, 0 };


	LightPropertiesConstantBuffer lightProperties;
	//lightProperties.EyePosition = g_Lighting.Position;
	lightProperties.EyePosition = temp4;
	lightProperties.Lights[0] = g_Lighting;
	g_pImmediateContext->UpdateSubresource(g_pLightConstantBuffer, 0, nullptr, &lightProperties, 0, 0);
}

float calculateDeltaTime()
{
	// Update our time
	static float deltaTime = 0.0f;
	static ULONGLONG timeStart = 0;
	ULONGLONG timeCur = GetTickCount64();
	if (timeStart == 0)
		timeStart = timeCur;
	deltaTime = (timeCur - timeStart) / 1000.0f;
	timeStart = timeCur;

	float FPS60 = 1.0f / 60.0f;
	static float cummulativeTime = 0;

	// cap the framerate at 60 fps 
	cummulativeTime += deltaTime;
	if (cummulativeTime >= FPS60) {
		cummulativeTime = cummulativeTime - FPS60;
	}
	else {
		return 0;
	}

	return deltaTime;
}

bool InitDirectInput(HINSTANCE hInstance)
{
	hr = DirectInput8Create(hInstance, DIRECTINPUT_VERSION, IID_IDirectInput8, (void**)&DirectInput, NULL);
	hr = DirectInput->CreateDevice(GUID_SysMouse, &DIMouse, NULL);
	hr = DIMouse->SetDataFormat(&c_dfDIMouse);
	hr = DIMouse->SetCooperativeLevel(g_hWnd, DISCL_FOREGROUND | DISCL_NOWINKEY);
	return true;
}

void DetectInput(double deltaTime)
{
	if (GetAsyncKeyState('W'))
	{
		currentPosZ += 0.1f * cos(rotationX);
		currentPosX += 0.1f * sin(rotationX);
	}
	if (GetAsyncKeyState('S'))
	{
		currentPosZ -= 0.1f * cos(rotationX);
		currentPosX -= 0.1f * sin(rotationX);
	}

	//DIMOUSESTATE mouseState;

	//DIMouse->Acquire();

	//DIMouse->GetDeviceState(sizeof(DIMOUSESTATE), &mouseState);

	//if (mouseState.lX != mouseLastState.lX)
	//{
	//	rotationX += (mouseState.lX * 0.002f);
	//}
	//if (mouseState.lY != mouseLastState.lY)
	//{
	//	rotationY -= (mouseState.lY * 0.002f);
	//}
	//mouseLastState = mouseState;

	return;
}

//--------------------------------------------------------------------------------------
// Constantly Updates The Scene 
//--------------------------------------------------------------------------------------
void UpdateCamera()
{
	float deltaTime = calculateDeltaTime(); // capped at 60 fps
	if (deltaTime == 0.0f)
		return;

	if (GetAsyncKeyState('5'))
	{
		Debug::GetInstance().DebugNum(5);
	}

	DetectInput(deltaTime);

	g_pCurrentCamera->SetPosition(XMFLOAT3(currentPosX - sin(rotationX), currentPosY, currentPosZ - cos(rotationX)));
	g_pCurrentCamera->SetLookAt(XMFLOAT3(currentPosX, rotationY, currentPosZ));
	g_pCurrentCamera->SetView();

	g_GameObject.update(deltaTime, g_pImmediateContext);

	g_pCurrentCamera->SetView();
	g_pCurrentCamera->SetProjection();
}

void IMGUI()
{
	// IMGUI
	ImGui_ImplDX11_NewFrame();
	ImGui_ImplWin32_NewFrame();
	ImGui::NewFrame();
	setupLightForRender();
	ImGui::Begin("Debug Window");

	ImGui::SetWindowSize(ImVec2(500.0f, 200.0f));

	if (ImGui::CollapsingHeader("Camera"))
	{
		std::string PositionX = "Position X: " + std::to_string(currentPosX);
		ImGui::Text(PositionX.c_str());

		std::string PositionY = "Position Y: " + std::to_string(currentPosY);
		ImGui::Text(PositionY.c_str());

		std::string PositionZ = "Position Z: " + std::to_string(currentPosZ);
		ImGui::Text(PositionZ.c_str());

		ImGui::DragFloat("Rotate on the X Axis", &rotationX, 0.005f);
		ImGui::DragFloat("Rotate on the Y Axis", &rotationY, 0.005f);
	}
	if (ImGui::CollapsingHeader("Lighting"))
	{
		ImGui::Text("Positions");
		ImGui::DragFloat("Light Position X", &g_Lighting.Position.x, 0.05f, -100.0f, 100.0f);
		ImGui::DragFloat("Light Position Y", &g_Lighting.Position.y, 0.05f, -100.0f, 100.0f);
		ImGui::DragFloat("Light Position Z", &g_Lighting.Position.z, 0.05f, -100.0f, 100.0f);

		ImGui::Text("Directions");
		ImGui::DragFloat("Light Direction X", &g_Lighting.Direction.x, 0.05f, -1.0f, 1.0f);
		ImGui::DragFloat("Light Direction Y", &g_Lighting.Direction.y, 0.05f, -1.0, 1.0f);
		ImGui::DragFloat("Light Direction Z", &g_Lighting.Direction.z, 0.05f, -1.0f, 1.0f);
	}
	if (ImGui::CollapsingHeader("Objects"))
	{
		ImGui::Text("Spin");
		if (ImGui::Checkbox("Spinning", &g_GameObject.isSpinning));
		ImGui::Text("Direction");
		ImGui::DragFloat("Object Position X", &g_GameObject.m_position.x, 0.025f);
		ImGui::DragFloat("Object Position Y", &g_GameObject.m_position.y, 0.025f);
		ImGui::DragFloat("Object Position Z", &g_GameObject.m_position.z, 0.025f);
	}

	ImGui::End();

	ImGui::Render();

	ImGui_ImplDX11_RenderDrawData(ImGui::GetDrawData());
}

//--------------------------------------------------------------------------------------
// Render a frame
//--------------------------------------------------------------------------------------
void Render()
{
	float t = calculateDeltaTime();

	// Clear the back buffer
	g_pImmediateContext->ClearRenderTargetView(g_pRenderTargetView, Colors::MidnightBlue);
	g_pImmediateContext->ClearRenderTargetView(g_pRenderTargetView, Colors::MidnightBlue);

	// Clear the depth buffer to 1.0 (max depth)
	g_pImmediateContext->ClearDepthStencilView(g_pDepthStencilView, D3D11_CLEAR_DEPTH, 1.0f, 0);
	g_pImmediateContext->OMSetRenderTargets(1, &g_pRenderTargetView, g_pDepthStencilView);

	g_GameObject.update(t, g_pImmediateContext);

	// get the game object world transform
	XMMATRIX mGO = XMLoadFloat4x4(g_GameObject.getTransform());
	XMMATRIX view = XMLoadFloat4x4(g_pCurrentCamera->GetView());
	XMMATRIX projection = XMLoadFloat4x4(g_pCurrentCamera->GetProjection());

	// store this and the view / projection in a constant buffer for the vertex shader to use
	ConstantBuffer cb1;
	cb1.mWorld = XMMatrixTranspose(mGO);
	cb1.mView = XMMatrixTranspose(view);
	cb1.mProjection = XMMatrixTranspose(projection);
	cb1.vOutputColor = XMFLOAT4(0, 0, 0, 0);
	cb1.fHeightScale = 1.0f;
	cb1.nMinSamples = 1.0f;
	cb1.nMaxSamples = 10.0f;
	g_pImmediateContext->UpdateSubresource(g_pConstantBuffer, 0, nullptr, &cb1, 0, 0);

	// Render the cube
	//Vertex Shader
	g_pImmediateContext->IASetInputLayout(g_pVertexLayout);

	g_pImmediateContext->VSSetShader(g_pVertexShader, nullptr, 0);
	g_pImmediateContext->VSSetConstantBuffers(0, 1, &g_pConstantBuffer);
	g_pImmediateContext->VSSetConstantBuffers(2, 1, &g_pLightConstantBuffer);

	//Pixel shader
	g_pImmediateContext->PSSetShader(g_pPixelShader, nullptr, 0);

	ID3D11Buffer* materialCB = g_GameObject.getMaterialConstantBuffer();
	g_pImmediateContext->PSSetConstantBuffers(1, 1, &materialCB);
	g_pImmediateContext->PSSetConstantBuffers(2, 1, &g_pLightConstantBuffer);

	g_pImmediateContext->PSSetShaderResources(0, 1, g_GameObject.getTextureResourceView());
	g_GameObject.draw(g_pImmediateContext);

	IMGUI();

	// Present our back buffer to our front buffer
	g_pSwapChain->Present(0, 0);
}

void RenderToTarget()
{
	float t = calculateDeltaTime();

	// First Render
	// Clear the back buffer
	g_pImmediateContext->ClearRenderTargetView(g_pRenderTargetView, Colors::MidnightBlue);
	g_pImmediateContext->ClearRenderTargetView(g_pRTTRenderTargetView, Colors::Green);

	// Clear the depth buffer to 1.0 (max depth)
	g_pImmediateContext->ClearDepthStencilView(g_pDepthStencilView, D3D11_CLEAR_DEPTH, 1.0f, 0);

	g_pImmediateContext->OMSetRenderTargets(1, &g_pRTTRenderTargetView, g_pDepthStencilView);

	g_GameObject.update(t, g_pImmediateContext);

	// get the game object world transform
	XMMATRIX mGO = XMLoadFloat4x4(g_GameObject.getTransform());
	XMMATRIX view = XMLoadFloat4x4(g_pCurrentCamera->GetView());
	XMMATRIX projection = XMLoadFloat4x4(g_pCurrentCamera->GetProjection());

	// store this and the view / projection in a constant buffer for the vertex shader to use
	ConstantBuffer cb1;
	cb1.mWorld = XMMatrixTranspose(mGO);
	cb1.mView = XMMatrixTranspose(view);
	cb1.mProjection = XMMatrixTranspose(projection);
	cb1.vOutputColor = XMFLOAT4(0, 0, 0, 0);
	cb1.fHeightScale = 1.0f;
	cb1.nMinSamples = 1.0f;
	cb1.nMaxSamples = 10.0f;
	g_pImmediateContext->UpdateSubresource(g_pConstantBuffer, 0, nullptr, &cb1, 0, 0);

	// Render the cube
	//Vertex Shader
	g_pImmediateContext->IASetInputLayout(g_pVertexLayout);

	g_pImmediateContext->VSSetShader(g_pVertexShader, nullptr, 0);
	g_pImmediateContext->VSSetConstantBuffers(0, 1, &g_pConstantBuffer);
	g_pImmediateContext->VSSetConstantBuffers(2, 1, &g_pLightConstantBuffer);

	//Pixel shader
	g_pImmediateContext->PSSetShader(g_pPixelShader, nullptr, 0);

	ID3D11Buffer* materialCB = g_GameObject.getMaterialConstantBuffer();
	g_pImmediateContext->PSSetConstantBuffers(1, 1, &materialCB);
	g_pImmediateContext->PSSetConstantBuffers(2, 1, &g_pLightConstantBuffer);

	g_pImmediateContext->PSSetShaderResources(0, 1, g_GameObject.getTextureResourceView());
	g_GameObject.draw(g_pImmediateContext);

	// Second Render

	g_pImmediateContext->OMSetRenderTargets(1, &g_pRenderTargetView, g_pDepthStencilView);

	// Clear the depth buffer to 1.0 (max depth)
	g_pImmediateContext->ClearDepthStencilView(g_pDepthStencilView, D3D11_CLEAR_DEPTH, 1.0f, 0);
	// Render the cube

	// Set VB and IB for Quad
	UINT stride = sizeof(SimpleVertexQuad);
	UINT offset = 0;
	g_pImmediateContext->IASetVertexBuffers(0, 1, &g_pQuadVB, &stride, &offset);
	g_pImmediateContext->IASetIndexBuffer(g_pQuadIB, DXGI_FORMAT_R16_UINT, 0);
	g_pImmediateContext->IASetInputLayout(g_pQuadLayout);


	//Vertex Shader
	g_pImmediateContext->VSSetShader(g_pQuadVS, nullptr, 0);
	//Pixel shader
	g_pImmediateContext->PSSetShader(g_pQuadPS, nullptr, 0);

	g_pImmediateContext->PSSetShaderResources(0, 1, &g_pRTTShaderResourceView);

	g_pImmediateContext->DrawIndexed(6, 0, 0);

	IMGUI();

	// Present our back buffer to our front buffer
	g_pSwapChain->Present(0, 0);

}