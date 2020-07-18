module sharpshooter.imports.shell32;

version (LDC) pragma(LDC_no_moduleinfo);

import aegis.importobfuscation;
import core.sys.windows.windows;

mixin template ImportUser32(alias function_, string file = __FILE__, size_t line = __LINE__)
{
	mixin Import!("shell32.dll", function_, file, line);
}

mixin ImportUser32!CommandLineToArgvW;
