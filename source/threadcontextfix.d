module sharpshooter.threadcontextfix;

import aegis.importobfuscation;
import aegis.stringencryption;
import core.sys.windows.windows;
import sharpshooter.utility;
import std.string;

void hookGetThreadContext()
{
	auto GetThreadContextAddress = getFunction!("kernel32.dll", "GetThreadContext");

	auto base = cast(ubyte*) moduleHandle;
	const dosHeader = cast(const(IMAGE_DOS_HEADER)*) base;
	const ntHeaders = cast(const(IMAGE_NT_HEADERS)*) (base + dosHeader.e_lfanew);
	immutable size = ntHeaders.OptionalHeader.SizeOfImage;

	for (size_t offset = 0; offset < size - size_t.sizeof; offset += size_t.sizeof)
	{
		auto pointer = cast(void**) (base + offset);
		if (*pointer == GetThreadContextAddress)
		{
			uint protection;
			enforceWin32!VirtualProtect(pointer, size_t.sizeof, PAGE_EXECUTE_READWRITE, &protection);
			scope(exit) enforceWin32!VirtualProtect(pointer, size_t.sizeof, protection, &protection);

			GetThreadContextOriginal = cast(typeof(GetThreadContextOriginal)) *pointer;
			*pointer = &GetThreadContextDetour;
			return;
		}
	}

	throw new Exception(encrypted!"Could not hook GetThreadContext.");
}

private
alias TGetThreadContext = extern (Windows) int function(HANDLE, CONTEXT*);

private
__gshared TGetThreadContext GetThreadContextOriginal;

private
extern (Windows)
int GetThreadContextDetour(HANDLE thread, CONTEXT* context)
{
	int result;
	size_t count = 0;
	do
	{
		if (count >= 1000)
		{
			log!"GetThreadContext fix failed.";
			return 0;
		}

		result = GetThreadContextOriginal(thread, context);
		++count;
	}
	while (!result);

	return result;
}
