module sharpshooter.imports.kernel32;

version (LDC) pragma(LDC_no_moduleinfo);

import aegis.importobfuscation;
import core.sys.windows.tlhelp32;
import core.sys.windows.windows;

mixin template ImportKernel32(alias function_, string file = __FILE__, size_t line = __LINE__)
{
	mixin Import!("kernel32.dll", function_, file, line);
}

mixin ImportKernel32!DeviceIoControl;
mixin ImportKernel32!CreateFileA;
mixin ImportKernel32!SetCurrentDirectoryA;
mixin ImportKernel32!GetLastError;
mixin ImportKernel32!FormatMessageW;
mixin ImportKernel32!GetConsoleWindow;
mixin ImportKernel32!Toolhelp32ReadProcessMemory;
mixin ImportKernel32!CreateToolhelp32Snapshot;
mixin ImportKernel32!Module32FirstW;
mixin ImportKernel32!CloseHandle;
mixin ImportKernel32!GetVolumeInformationA;
mixin ImportKernel32!GetComputerNameA;
mixin ImportKernel32!LocalFree;
mixin ImportKernel32!GetCommandLineW;
mixin ImportKernel32!TerminateProcess;
mixin ImportKernel32!GetCurrentProcess;
mixin ImportKernel32!OpenProcess;
mixin ImportKernel32!ReadProcessMemory;
