module sharpshooter.memory;

import core.sys.windows.tlhelp32;
import core.sys.windows.windows;
import sharpshooter.driver;
import sharpshooter.imports.kernel32;
import sharpshooter.settings;
import sharpshooter.utility;
import std.exception;

/// A memory region
struct Region
{
	size_t baseAddress;
	size_t length;
}

/// A memory object
class MemoryObject
{
	/// Constructor
	this(size_t baseAddress)
	{
		_baseAddress = baseAddress;
	}

	/// Get the base address.
	size_t baseAddress() const @property
	{
		return _baseAddress;
	}

	/// Read a field.
	T field(T)(size_t offset) const
	{
		return read!T(baseAddress + offset);
	}

	private
	size_t _baseAddress;
}

/// The game process ID
__gshared uint gameProcessID;

/// The main module base address
__gshared size_t mainModule;

/// Attach to a game process.
void attach(uint id)
{
	gameProcessID = id;

	version (Driver)
	{
		mainModule = getProcessBase(id);
	}
	else
	{
		auto snapshot = enforceWin32!(createToolhelp32Snapshot, "a != INVALID_HANDLE_VALUE")(TH32CS_SNAPMODULE, id);
		scope(exit) closeHandle(snapshot);

		MODULEENTRY32W moduleEntry;
		moduleEntry.dwSize = moduleEntry.sizeof;
		enforceWin32!module32FirstW(snapshot, &moduleEntry);

		mainModule = cast(size_t) moduleEntry.modBaseAddr;
	}

	_process = enforceWin32!openProcess(PROCESS_ALL_ACCESS, false, id);
}

/// Read bytes from the game process into a byte array.
void read(size_t address, void* bytes, size_t length, bool safe = false)
{
	version (DriverMemoryReading)
	{
		enforce(!safe || isReadable(address));
		/*if (safe)
		{
			checkTrapPage(address);
		}*/
		
		copyVirtualMemory(gameProcessID, address, length, bytes, false);
	}
	else
	{
		enforceWin32!readProcessMemory(_process, cast(const(void)*) address, bytes, length, null);
	}
}

/// Try to read bytes from the game process into a byte array.
bool tryRead(size_t address, void* bytes, size_t length, bool safe = false)
{
	version (DriverMemoryReading)
	{
		enforce(!safe || isReadable(address));
		/*if (safe)
		{
			checkTrapPage(address);
		}*/
		
		return copyVirtualMemory(gameProcessID, address, length, bytes, false, false);
	}
	else
	{
		return cast(bool) readProcessMemory(_process, cast(const(void)*) address, bytes, length, null);
	}
}

/// Read an array from the game process.
T[] read(T)(size_t address, size_t length, bool safe = false)
{
	auto array = new T[length];
	read(address, array.ptr, T.sizeof * array.length, safe);
	return array;
}

/// Read a value from the game process.
T read(T)(size_t address, bool safe = false)
{
	T value;
	read(address, &value, value.sizeof, safe);
	return value;
}

/// Get whether an address is readable.
bool isReadable(size_t address)
{
	version (Driver)
	{
		const region = virtualQuery(gameProcessID, address);
	}
	else
	{
		MEMORY_BASIC_INFORMATION region;
		auto process = enforceWin32!OpenProcess(PROCESS_QUERY_INFORMATION, false, gameProcessID);
		scope(exit) closeHandle(process);
		VirtualQueryEx(process, cast(void*) address, &region, region.sizeof);
	}
	
	return (region.State == MEM_COMMIT && region.Protect != PAGE_NOACCESS) || !region.State;
}

/// Check whether a page is a trap page, and print a message if it is.
void checkTrapPage(size_t address)
{
	auto process = OpenProcess(PROCESS_ALL_ACCESS, false, gameProcessID);
	scope(exit) CloseHandle(process);
	PSAPI_WORKING_SET_EX_INFORMATION information;
	information.virtualAddress = address;
	enforceWin32!QueryWorkingSetEx(process, &information, cast(uint) information.sizeof);
	if (!(information.flags & 1) && isReadable(address))
	{
		import aegis.stringencryption;
		import std.format;
		import std.string;
		immutable message = format(encrypted!"Tried to read trap page at 0x%X", address);
		log!"%s"(message);
		import sharpshooter.imports.user32;
		messageBoxA(null, message.toStringz, encrypted!"Sharpshooter - Error".toStringz, MB_OK);
	}
}

struct PSAPI_WORKING_SET_EX_INFORMATION
{
	size_t virtualAddress;
	size_t flags;
}

extern (Windows)
int QueryWorkingSetEx(HANDLE process, PSAPI_WORKING_SET_EX_INFORMATION* information, uint bytes);

//private
HANDLE _process;
