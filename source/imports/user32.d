module sharpshooter.imports.user32;

version (LDC) pragma(LDC_no_moduleinfo);

import aegis.importobfuscation;
import core.sys.windows.windows;

mixin template ImportUser32(alias function_, string file = __FILE__, size_t line = __LINE__)
{
	mixin Import!("user32.dll", function_, file, line);
}

mixin ImportUser32!SetWindowTextA;
mixin ImportUser32!GetWindowThreadProcessId;
mixin ImportUser32!PeekMessageA;
mixin ImportUser32!TranslateMessage;
mixin ImportUser32!DispatchMessageA;
mixin ImportUser32!MessageBoxA;
mixin ImportUser32!GetKeyState;
mixin ImportUser32!FindWindowA;
mixin ImportUser32!SendInput;
mixin ImportUser32!IsWindowVisible;
mixin ImportUser32!ShowWindow;
mixin ImportUser32!RegisterClassExA;
mixin ImportUser32!GetWindowRect;
mixin ImportUser32!CreateWindowExA;
mixin ImportUser32!SetLayeredWindowAttributes;
mixin ImportUser32!DestroyWindow;
mixin ImportUser32!UnregisterClassA;
