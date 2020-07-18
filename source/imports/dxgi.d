module sharpshooter.imports.dxgi;

version (LDC) pragma(LDC_no_moduleinfo);

import aegis.importobfuscation;
import core.sys.windows.tlhelp32;
import core.sys.windows.windows;

mixin template ImportDXGI(alias function_, string file = __FILE__, size_t line = __LINE__)
{
	mixin Import!("dxgi.dll", function_, file, line);
}

extern (Windows)
HRESULT CreateDXGIFactory2(uint flags, const(void)* riid, void** factory);

mixin ImportDXGI!CreateDXGIFactory2;
