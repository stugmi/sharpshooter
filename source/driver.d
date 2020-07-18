module sharpshooter.driver;

version (Driver):

import aegis.stringencryption;
import core.sys.windows.windows;
import sharpshooter.imports.kernel32;
import sharpshooter.utility;
import std.string;
import vmprotect;

struct MouseInputData
{
	ushort unitID;
	ushort flags;
	ushort buttonFlags;
	ushort buttonData;
	uint rawButtons;
	int lastX;
	int lastY;
	uint extraInformation;
}

// copying virtual memory from address
bool copyVirtualMemory(uint pid, ulong address, ulong size, void* buffer, bool write, bool enforce = true)
{
	CopyMemory memory;

	memory.buffer = cast(ulong) buffer;
	memory.address = address;
	memory.size = size;
	memory.processID = pid;
	memory.write = write;

	if (enforce)
	{
		enforceWin32!deviceIoControl(handle, IOCTL_COPY_VIRTUALMEMORY,
			&memory, cast(uint) memory.sizeof, null, 0, null, null);
		return true;
	}
	else
	{
		return cast(bool) deviceIoControl(handle, IOCTL_COPY_VIRTUALMEMORY,
			&memory, cast(uint) memory.sizeof, null, 0, null, null);
	}
}

// query memory region
MEMORY_BASIC_INFORMATION virtualQuery(uint pid, ulong address)
{
	VIRTUAL_QUERY query;
	query.processID = pid;
	query.address = address;
	MEMORY_BASIC_INFORMATION region;
	query.region = &region;

	deviceIoControl(handle, IOCTL_VIRTUAL_QUERY, &query, cast(uint) query.sizeof,
		&query, cast(uint) query.sizeof, null, null);
	return region;
}

// get process base address
size_t getProcessBase(uint pid)
{
	InOutParam param;
	param.Param1 = pid;

	enforceWin32!deviceIoControl(handle, IOCTL_GET_PROCESS_BASE_ADDRESS, &param, cast(uint) param.sizeof,
		&param, cast(uint) param.sizeof, null, null);

	return param.Param1;
}

// register callback so no program can open a handle to it
bool registerCallback()
{
	InOutParam param;
	param.Param1 = GetCurrentProcessId;
	
	return cast(bool) deviceIoControl(handle, IOCTL_OB_REGISTER_CALLBACK, &param, cast(uint) param.sizeof,
		null, 0, null, null);
}

// unregister the callback
void unregisterCallback()
{
	enforceWin32!deviceIoControl(handle, IOCTL_OB_UNREGISTER_CALLBACK, null, 0, null, 0, null, null);
}

/// set the processe id
void setProcessID(uint targetProcessID, uint newProcessID)
{
	InOutParam param;
	param.Param1 = newProcessID;
	param.Param2 = targetProcessID;
	enforceWin32!deviceIoControl(handle, IOCTL_HIDE_PROCESS, &param, cast(uint) param.sizeof, null, 0, null, null);
}

/// send mouse input
void mouseInput(ref MouseInputData input)
{
	enforceWin32!deviceIoControl(handle, IOCTL_MOUSE_INPUT, &input, cast(uint) input.sizeof, null, 0, null, null);
}

// open handle to device driver gpu io
void openDeviceHandle()
{
	handle = enforceWin32!(createFileA, "a != INVALID_HANDLE_VALUE")(
		encrypted!"\\\\.\\GPUIo".toStringz,
		GENERIC_READ | GENERIC_WRITE,
		FILE_SHARE_READ | FILE_SHARE_WRITE,
		null,
		OPEN_EXISTING,
		0,
		null);
}

// ctl code
private
template CTL_CODE(uint t, uint f, uint m, uint a)
{
	enum CTL_CODE = (t << 16) | (a << 14) | (f << 2) | m;
}

// device unknown
private
enum FILE_DEVICE_UNKNOWN = 0x00000022;

// file read access
private
enum FILE_READ_ACCESS = 0x0001;

// file write access
private
enum FILE_WRITE_ACCESS = 0x0002;

// method buffered
private
enum METHOD_BUFFERED = 0x0;

// copying virtual memory
private
enum IOCTL_COPY_VIRTUALMEMORY = CTL_CODE!(FILE_DEVICE_UNKNOWN, 0x5001, METHOD_BUFFERED, FILE_READ_ACCESS | FILE_WRITE_ACCESS);

// get process base address
private
enum IOCTL_GET_PROCESS_BASE_ADDRESS = CTL_CODE!(FILE_DEVICE_UNKNOWN, 0x5002, METHOD_BUFFERED, FILE_READ_ACCESS | FILE_WRITE_ACCESS);

// register callbacks
private
enum IOCTL_OB_REGISTER_CALLBACK = CTL_CODE!(FILE_DEVICE_UNKNOWN, 0x5003, METHOD_BUFFERED, FILE_READ_ACCESS | FILE_WRITE_ACCESS);

// unregister callbacks
private
enum IOCTL_OB_UNREGISTER_CALLBACK = CTL_CODE!(FILE_DEVICE_UNKNOWN, 0x5004, METHOD_BUFFERED, FILE_READ_ACCESS | FILE_WRITE_ACCESS);

// set process id
private
enum IOCTL_HIDE_PROCESS = CTL_CODE!(FILE_DEVICE_UNKNOWN, 0x5006, METHOD_BUFFERED, FILE_READ_ACCESS | FILE_WRITE_ACCESS);

// mouse input
private
enum IOCTL_MOUSE_INPUT = CTL_CODE!(FILE_DEVICE_UNKNOWN, 0x5007, METHOD_BUFFERED, FILE_READ_ACCESS | FILE_WRITE_ACCESS);

// mouse input
private
enum IOCTL_VIRTUAL_QUERY = CTL_CODE!(FILE_DEVICE_UNKNOWN, 0x5019, METHOD_BUFFERED, FILE_READ_ACCESS | FILE_WRITE_ACCESS);

//memory copying struct TRUE if write operation, FALSE if read
private
struct CopyMemory
{
	ulong buffer;
	ulong address;
	ulong size;
	ulong processID;
	bool write;
}

private
struct InOutParam
{
	ulong Param1;
	ulong Param2;
	ulong Param3;
	ulong Param4;
}

private
struct VIRTUAL_QUERY
{
	ulong processID;
	ulong address;
	MEMORY_BASIC_INFORMATION* region;
}

private
__gshared HANDLE handle;
