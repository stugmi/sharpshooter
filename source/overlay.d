module sharpshooter.overlay;

import aegis.stringencryption;
import core.stdc.string;
import core.sys.windows.windows;
import directx.d3d11;
import directx.dcomp;
import directx.dxgi1_3;
import directx.d3dcompiler;
import directx.win32;
import sharpshooter.imports.dxgi;
import sharpshooter.imports.user32;
import sharpshooter.settings;
import sharpshooter.utility;
import sharpshooter.vector;
import sharpshooter.view;
import sharpshooter.window;
import std.array;
import std.conv;
import std.exception;
import std.math;
import std.string;

/// A vertex
struct Vertex
{
	Vector2 position;
	Color color;
}

/// A color
struct Color
{
	float red;
	float green;
	float blue;
	float alpha;
}

/// Get whether the overlay is active.
bool overlayActive()
{
	return setting!(bool, "OverlayEnabled")
		&& getKeyState(setting!(uint, "OverlayKey")) < 0
		/*&& isForeground*/;
}

/// Get whether the overlay is visible.
bool overlayVisible()
{
	return cast(bool) overlayWindow;
}

/// Update the overlay.
void updateOverlay()
{
	if (setting!(bool, "OverlayEnabled") != overlayVisible)
	{
		if (overlayWindow)
		{
			destroyOverlay;
			log!"Destroyed overlay.";
		}
		else
		{
			createOverlay;
			log!"Created overlay.";
		}
	}

	if (overlayVisible)
	{
		immutable active = overlayActive;
		if (active != isWindowVisible(overlayWindow))
		{
			RECT newGameWindowRect;
			getWindowRect(gameWindow, &newGameWindowRect);
			static __gshared RECT gameWindowRect;
			if (newGameWindowRect != gameWindowRect)
			{
				gameWindowRect = newGameWindowRect;
				destroyOverlay;
				createOverlay;
			}

			showWindow(overlayWindow, active ? SW_SHOW : SW_HIDE);
		}

		processMessages;
		if (active)
		{
			renderFrame;
		}
		else
		{
			vertices.clear;
		}
	}
}

/// Draw a line.
void drawLine(Vertex from, Vertex to, float fromThickness, float toThickness)
{
	immutable angle = from.position.angle(to.position);
	immutable fromDistance = fromThickness / 2;
	immutable toDistance = toThickness / 2;

	// Adjust so that the lines connect properly
	immutable adjustedFrom = from.position.translate(-fromDistance, angle);
	immutable adjustedTo = to.position.translate(toDistance, angle);

	immutable first = adjustedFrom.translate(fromDistance, angle + PI_2);
	immutable second = adjustedFrom.translate(fromDistance, angle - PI_2);
	immutable third = adjustedTo.translate(toDistance, angle - PI_2);
	immutable fourth = adjustedTo.translate(toDistance, angle + PI_2);

	drawFilledRectangle(
		Vertex(first, from.color),
		Vertex(second, from.color),
		Vertex(third, to.color),
		Vertex(fourth, to.color),
	);
}

/// Draw a line in the game world.
void drawLine(Vector3 from, Vector3 to, Color color, float thickness = 1.0F)
{
	immutable fromScreen = worldToScreen(from);
	immutable toScreen = worldToScreen(to);
	if (!fromScreen.isNull && !toScreen.isNull)
	{
		drawLine(
			Vertex(fromScreen.get, color),
			Vertex(toScreen.get, color),
			thickness * 0.05 / cameraPosition.distance(from),
			thickness * 0.05 / cameraPosition.distance(to),
		);
	}
}

/// Draw a triangle in the game world.
void drawTriangle(Vector3 first, Vector3 second, Vector3 third, Color color)
{
	immutable firstScreen = worldToScreen(first);
	immutable secondScreen = worldToScreen(second);
	immutable thirdScreen = worldToScreen(third);
	if (!firstScreen.isNull && !secondScreen.isNull && !thirdScreen.isNull)
	{
		drawFilledTriangle(
			Vertex(firstScreen.get, color),
			Vertex(secondScreen.get, color),
			Vertex(thirdScreen.get, color),
		);
	}
}

/// Draw a filled rectangle.
void drawFilledRectangle(
	Vertex first,
	Vertex second,
	Vertex third,
	Vertex fourth)
{
	drawFilledTriangle(fourth, second, first);
	drawFilledTriangle(third, second, fourth);
}

/// Draw a filled triangle.
void drawFilledTriangle(Vertex first, Vertex second, Vertex third)
{
	vertices.put(first);
	vertices.put(second);
	vertices.put(third);
}

shared static this()
{
	className = generateRandomString;
	shaders = encrypted!(import("shaders.hlsl"));
}

private
enum DXGI_PRESENT_ALLOW_TEARING = 0x200;

private
enum DXGI_SWAP_CHAIN_FLAG_ALLOW_TEARING = 0x800;

private
immutable string className;

private
immutable string shaders;

private
immutable maximumVertices = 1000000;

private
__gshared HWND overlayWindow;

private
__gshared ID3D11Device device;

private
__gshared IDXGISwapChain1 swapChain;

private
__gshared ID3D11DeviceContext context;

private
__gshared ID3D11Buffer vertexBuffer;

private
__gshared ID3D11RenderTargetView backBuffer;

private
__gshared Appender!(Vertex[]) vertices;

private
void createOverlay()
{
	WNDCLASSEXA windowClass;
	windowClass.cbSize = windowClass.sizeof;
	windowClass.style = CS_HREDRAW | CS_VREDRAW;
	windowClass.lpszClassName = className.toStringz;
	windowClass.lpfnWndProc = &DefWindowProcA;
	enforceWin32!registerClassExA(&windowClass);

	RECT rect;
	getWindowRect(gameWindow, &rect);

	enum WS_EX_NOREDIRECTIONBITMAP = 0x200000;
	overlayWindow = enforceWin32!createWindowExA(
		WS_EX_NOREDIRECTIONBITMAP | WS_EX_LAYERED | WS_EX_TRANSPARENT | WS_EX_TOPMOST | WS_EX_NOACTIVATE,
		className.toStringz,
		className.toStringz,
		WS_POPUP | WS_VISIBLE,
		rect.left,
		rect.top,
		rect.right - rect.left,
		rect.bottom - rect.top,
		null, null, null, null);
	
	setLayeredWindowAttributes(overlayWindow, RGB(0, 0, 0), ubyte.max, ULW_COLORKEY | LWA_ALPHA);

	processMessages;
	createDeviceAndSwapChain;
	createBackBuffer;
	createViewport;
	createShaders;
	createVertexBuffer;
}

private
void destroyOverlay()
{
	DestroyWindow(overlayWindow);
	overlayWindow = null;
	enforceWin32!unregisterClassA(className.toStringz, null);
	device.Release;
	swapChain.Release;
	context.Release;
	vertexBuffer.Release;
	backBuffer.Release;
	vertices.clear;
	processMessages;
}

private
void processMessages()
{
	MSG message;
	while (peekMessageA(&message, null, 0, 0, PM_REMOVE))
	{
		translateMessage(&message);
		dispatchMessageA(&message);
	}
}

private
void renderFrame()
{
	context.ClearRenderTargetView(backBuffer, [0.0F, 0.0F, 0.0F, 0.0F].ptr);
	context.OMSetRenderTargets(1, &backBuffer, null);

	immutable vertexCount = cast(uint) vertices.data.length;
	enforce(vertexCount < maximumVertices, encrypted!"Too many vertices.");
	if (vertexCount)
	{
		D3D11_MAPPED_SUBRESOURCE resource;
		enforce(context.Map(vertexBuffer, 0, D3D11_MAP_WRITE_DISCARD, 0, &resource) == S_OK);
		memcpy(resource.pData, vertices.data.ptr, vertexCount * Vertex.sizeof);
		context.Unmap(vertexBuffer, 0);
		vertices.clear;
	}

	context.IASetPrimitiveTopology(D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST);
	context.Draw(vertexCount, 0);

	enforce(swapChain.Present(0, DXGI_PRESENT_ALLOW_TEARING) == S_OK);
}

private
void createDeviceAndSwapChain()
{
	auto featureLevel = D3D_FEATURE_LEVEL_11_0;
	enforceCOM!D3D11CreateDevice(
		null,
		D3D_DRIVER_TYPE_HARDWARE,
		null,
		D3D11_CREATE_DEVICE_BGRA_SUPPORT | D3D11_CREATE_DEVICE_SINGLETHREADED,
		&featureLevel,
		1,
		D3D11_SDK_VERSION,
		&device,
		null,
		&context);

	IDXGIFactory2 factory;
	enforceCOM!createDXGIFactory2(0, &IID_IDXGIFactory2, cast(void**) &factory);

	DXGI_SWAP_CHAIN_DESC1 description;
	description.Format = DXGI_FORMAT_B8G8R8A8_UNORM;
	description.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
	description.SwapEffect = DXGI_SWAP_EFFECT_FLIP_SEQUENTIAL;
	description.BufferCount = 2;
	description.SampleDesc.Count = 1;
	description.AlphaMode = DXGI_ALPHA_MODE_PREMULTIPLIED;
	description.Flags = DXGI_SWAP_CHAIN_FLAG_ALLOW_TEARING;

	RECT rect;
	getWindowRect(overlayWindow, &rect);
	description.Width = rect.right - rect.left;
	description.Height = rect.bottom - rect.top;

	enforce(factory.CreateSwapChainForComposition(cast(IDXGIDevice) device, &description, null, &swapChain) == S_OK);

	IDCompositionDevice compositionDevice;
	enforceCOM!DCompositionCreateDevice(
		cast(IDXGIDevice) device,
		&IID_IDCompositionDevice,
		cast(void**) &compositionDevice);

	IDCompositionTarget compositionTarget;
	enforce(compositionDevice.CreateTargetForHwnd(overlayWindow, true, &compositionTarget) == S_OK);

	IDCompositionVisual compositionVisual;
	enforce(compositionDevice.CreateVisual(&compositionVisual) == S_OK);

	enforce(compositionVisual.SetContent(swapChain) == S_OK);
	enforce(compositionTarget.SetRoot(compositionVisual) == S_OK);
	enforce(compositionDevice.Commit == S_OK);
}

private
void createShaders()
{
	ID3DBlob vertexShaderBlob;
	enforceCOM!D3DCompile(cast(const(void)*) shaders.ptr, shaders.length, null, null, null,
		encrypted!"VS".toStringz, encrypted!"vs_4_0".toStringz, 0, 0, &vertexShaderBlob, null);

	ID3D11VertexShader vertexShader;
	enforce(device.CreateVertexShader(vertexShaderBlob.GetBufferPointer,
		vertexShaderBlob.GetBufferSize, null, &vertexShader) == S_OK);
	context.VSSetShader(vertexShader, null, 0);

	ID3DBlob pixelShaderBlob;
	enforceCOM!D3DCompile(cast(const(void)*) shaders.ptr, shaders.length, null, null, null,
		encrypted!"PS".toStringz, encrypted!"ps_4_0".toStringz, 0, 0, &pixelShaderBlob, null);

	ID3D11PixelShader pixelShader;
	enforce(device.CreatePixelShader(pixelShaderBlob.GetBufferPointer,
		pixelShaderBlob.GetBufferSize, null, &pixelShader) == S_OK);
	context.PSSetShader(pixelShader, null, 0);

	D3D11_INPUT_ELEMENT_DESC[] layout = [
		D3D11_INPUT_ELEMENT_DESC(encrypted!"POSITION".toStringz, 0, DXGI_FORMAT_R32G32_FLOAT,
			0, 0, D3D11_INPUT_PER_VERTEX_DATA, 0),
		D3D11_INPUT_ELEMENT_DESC(encrypted!"COLOR".toStringz, 0, DXGI_FORMAT_R32G32B32A32_FLOAT,
			0, 8, D3D11_INPUT_PER_VERTEX_DATA, 0),
	];

	ID3D11InputLayout inputLayout;
	enforce(device.CreateInputLayout(layout.ptr, cast(uint) layout.length,
		vertexShaderBlob.GetBufferPointer, vertexShaderBlob.GetBufferSize, &inputLayout) == S_OK);
	context.IASetInputLayout(inputLayout);
}

private
void createVertexBuffer()
{
	D3D11_BUFFER_DESC buffer;
	memset(&buffer, 0, buffer.sizeof);
	buffer.Usage = D3D11_USAGE_DYNAMIC;
	buffer.ByteWidth = Vertex.sizeof * maximumVertices;
	buffer.BindFlags = D3D11_BIND_VERTEX_BUFFER;
	buffer.CPUAccessFlags = D3D11_CPU_ACCESS_WRITE;

	enforce(device.CreateBuffer(&buffer, null, &vertexBuffer) == S_OK);

	uint stride = Vertex.sizeof;
	uint offset = 0;
	context.IASetVertexBuffers(0, 1, &vertexBuffer, &stride, &offset);
}

private
void createBackBuffer()
{
	ID3D11Texture2D backBufferAddress;
	swapChain.GetBuffer(0, &IID_ID3D11Texture2D, cast(void**) &backBufferAddress);
	device.CreateRenderTargetView(backBufferAddress, null, &backBuffer);
	backBufferAddress.Release;
}

private
void createViewport()
{
	RECT rect;
	getWindowRect(overlayWindow, &rect);

	D3D11_VIEWPORT viewport;
	viewport.TopLeftX = 0;
	viewport.TopLeftY = 0;
	viewport.Width = rect.right - rect.left;
	viewport.Height = rect.bottom - rect.top;
	viewport.MinDepth = 1;
	viewport.MaxDepth = 1;
	context.RSSetViewports(1, &viewport);
}
