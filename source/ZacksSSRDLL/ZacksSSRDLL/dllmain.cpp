// dllmain.cpp : Defines the entry point for the DLL application.
#include "pch.h"

#include <d3d9.h>
#include "../packages/Microsoft.DXSDK.D3DX.9.29.952.8/build/native/include/d3dx9.h"
#include "../packages/Microsoft.DXSDK.D3DX.9.29.952.8/build/native/include/d3dx9effect.h"
#include "../packages/Microsoft.DXSDK.D3DX.9.29.952.8/build/native/include/D3dx9tex.h"


#define device (*(LPDIRECT3DDEVICE9*)0x008DA788)
#define hWnd (*(HWND*)0x008DA79C)

// I'm trying to figure out an upgrade where it also gets the depth buffer so real SSR can be done
//#define GetDepthBuffer

struct Shader
{
    BYTE pad_0x0[0x54];
    LPD3DXEFFECT pEffect_0x54;
    BYTE pad_0x58[16];
    D3DXHANDLE hTex0_0x68;
    D3DXHANDLE hTex1_0x6c;
    D3DXHANDLE hTex2_0x70;
    D3DXHANDLE hTex3_0x74;
    D3DXHANDLE mCub_0x78;
    D3DXHANDLE dFac_0x7c;
    D3DXHANDLE vDiff_0x80;
};

LPDIRECT3DTEXTURE9 backBuffer = NULL;
LPDIRECT3DTEXTURE9 depthBuffer = NULL;

void CreateTextureFromSurface(IDirect3DSurface9* surface, LPDIRECT3DTEXTURE9* out_texture)
{
    RECT windowRect;
    GetWindowRect(hWnd, &windowRect);

    D3DSURFACE_DESC desc;
    surface->GetDesc(&desc);
    device->CreateTexture(windowRect.right, windowRect.bottom, 1, desc.Usage, desc.Format, desc.Pool, &backBuffer, NULL);
}

void CopySurfaceToTexture(IDirect3DSurface9* src, LPDIRECT3DTEXTURE9 dst)
{
    IDirect3DSurface9* dstSurface;
    if (SUCCEEDED(dst->GetSurfaceLevel(0, &dstSurface)))
    {
        device->StretchRect(src, NULL, dstSurface, NULL, D3DTEXF_NONE);
        dstSurface->Release();
    }
}

extern "C"
{
    __declspec(dllexport) extern void _stdcall CreateTextures()
    {
        if (!backBuffer)
        {
            IDirect3DSurface9* srcSurface;

            if (SUCCEEDED(device->GetBackBuffer(0, 0, D3DBACKBUFFER_TYPE_LEFT, &srcSurface)))
            {
                CreateTextureFromSurface(srcSurface, &backBuffer);
                srcSurface->Release();
            }
        }

#ifdef GetDepthBuffer
        if (!depthBuffer)
        {
            IDirect3DSurface9* depthSurface;
            if (SUCCEEDED(device->GetDepthStencilSurface(&depthSurface)))
            {
                CreateTextureFromSurface(depthSurface, &depthBuffer);
                depthSurface->Release();
            }
        }
#endif
    }

    __declspec(dllexport) extern void __stdcall GetBackBuffer()
    {
        CreateTextures();

        IDirect3DSurface9* srcSurface;
        if (SUCCEEDED(device->GetBackBuffer(0, 0, D3DBACKBUFFER_TYPE_LEFT, &srcSurface)))
        {
            CopySurfaceToTexture(srcSurface, backBuffer);
            srcSurface->Release();
        }

#ifdef GetBackBuffer
        if (SUCCEEDED(device->GetDepthStencilSurface(&srcSurface)))
        {
            CopySurfaceToTexture(srcSurface, depthBuffer);
            srcSurface->Release();
        }
#endif
    }

    __declspec(dllexport) extern bool __stdcall TextureExists(LPD3DXEFFECT effect, char* handle)
    {
        LPDIRECT3DBASETEXTURE9 t;
        return SUCCEEDED(effect->GetTexture(handle, &t));
    }

    __declspec(dllexport) extern void __stdcall UpdateTextures(Shader* shader, char* handle)
    {
        shader->pEffect_0x54->SetTexture(handle, backBuffer);
#ifdef GetDepthBuffer
        shader->pEffect_0x54->SetTexture("Tex5", depthBuffer);
#endif
    }
}

BOOL APIENTRY DllMain( HMODULE hModule,
                       DWORD  ul_reason_for_call,
                       LPVOID lpReserved
                     )
{
    switch (ul_reason_for_call)
    {
    case DLL_PROCESS_ATTACH:
    case DLL_THREAD_ATTACH:
    case DLL_THREAD_DETACH:
        break;

    case DLL_PROCESS_DETACH:
        backBuffer->Release();
#ifdef GetDepthBuffer
        depthBuffer->Release();
#endif
        break;
    }
    return TRUE;
}

