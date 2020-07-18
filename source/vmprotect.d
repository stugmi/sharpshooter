module vmprotect;

version (LDC) pragma(LDC_no_moduleinfo);

import std.exception;
import std.string;

enum VMProtectSerialStateFlags
{
	success         = 0,
	corrupted       = 1 << 0,
	invalid         = 1 << 1,
	blacklisted     = 1 << 2,
	expired         = 1 << 3,
	runningTimeOver = 1 << 4,
	badHardwareID   = 1 << 5,
	buildExpired    = 1 << 6,
};

enum VMProtectActivationFlags
{
	ok = 0,
	smallBuffer,
	noConnection,
	badReply,
	banned,
	corrupted,
	badCode,
	alreadyUsed,
	serialUnknown,
	expired,
	notAvailable,
};

struct VMProtectDate
{
align (1):

	ushort year;
	ubyte month;
	ubyte day;
}

struct VMProtectSerialNumberData
{
align (1):

	int state;
	wchar[256] username;
	wchar[256] email;
	VMProtectDate expireDate;
	VMProtectDate maxBuildDate;
	int runningTimeMinutes;
	ubyte userDataLength;
	ubyte[255] userData;
}

version (VMProtect)
{
	extern (Windows)
	void VMProtectBegin(const(char)* marker);

	extern (Windows)
	void VMProtectBeginVirtualization(const(char)* marker);

	extern (Windows)
	void VMProtectBeginMutation(const(char)* marker);

	extern (Windows)
	void VMProtectBeginUltra(const(char)* marker);

	extern (Windows)
	void VMProtectBeginVirtualizationLockByKey(const(char)* marker);

	extern (Windows)
	void VMProtectBeginUltraLockByKey(const(char)* marker);

	extern (Windows)
	void VMProtectEnd();

	extern (Windows)
	bool VMProtectIsProtected();

	extern (Windows)
	bool VMProtectIsDebuggerPresent(bool checkKernelMode);

	extern (Windows)
	bool VMProtectIsVirtualMachinePresent();

	extern (Windows)
	bool VMProtectIsValidImageCRC();

	extern (Windows)
	const(char)* VMProtectDecryptStringA(const(char)* value);

	extern (Windows)
	const(wchar)* VMProtectDecryptStringW(const(wchar)* value);

	extern (Windows)
	bool VMProtectFreeString(const(void)* value);

	extern (Windows)
	int VMProtectSetSerialNumber(const(char)* serial);

	extern (Windows)
	int VMProtectGetSerialNumberState();

	extern (Windows)
	bool VMProtectGetSerialNumberData(out VMProtectSerialNumberData data, int size);

	extern (Windows)
	int VMProtectGetCurrentHWID(char* hwid, int size);

	extern (Windows)
	int VMProtectActivateLicense(const(char)* code, char* serial, int size);

	extern (Windows)
	int VMProtectDeactivateLicense(const(char)* serial);

	extern (Windows)
	int VMProtectGetOfflineActivationString(const(char)* code, char* buffer, int size);

	extern (Windows)
	int VMProtectGetOfflineDeactivationString(const(char)* serial, char* buffer, int size);
}
else
{
	pragma(msg, "Warning: compiling without VMProtect. Use the VMProtect version to enable it.");

	extern (Windows)
	void VMProtectBegin(const(char)* marker)
	{ }

	extern (Windows)
	void VMProtectBeginVirtualization(const(char)* marker)
	{ }

	extern (Windows)
	void VMProtectBeginMutation(const(char)* marker)
	{ }

	extern (Windows)
	void VMProtectBeginUltra(const(char)* marker)
	{ }

	extern (Windows)
	void VMProtectBeginVirtualizationLockByKey(const(char)* marker)
	{ }

	extern (Windows)
	void VMProtectBeginUltraLockByKey(const(char)* marker)
	{ }

	extern (Windows)
	void VMProtectEnd()
	{ }

	extern (Windows)
	bool VMProtectIsProtected()
	{ return false; }

	extern (Windows)
	bool VMProtectIsDebuggerPresent(bool checkKernelMode)
	{ return false; }

	extern (Windows)
	bool VMProtectIsVirtualMachinePresent()
	{ return false; }

	extern (Windows)
	bool VMProtectIsValidImageCRC()
	{ return true; }

	extern (Windows)
	const(char)* VMProtectDecryptStringA(const(char)* value)
	{ assert(0); }

	extern (Windows)
	const(wchar)* VMProtectDecryptStringW(const(wchar)* value)
	{ assert(0); }

	extern (Windows)
	bool VMProtectFreeString(const(void)* value)
	{ assert(0); }

	extern (Windows)
	int VMProtectSetSerialNumber(const(char)* serial)
	{ assert(0); }

	extern (Windows)
	int VMProtectGetSerialNumberState()
	{ assert(0); }

	extern (Windows)
	bool VMProtectGetSerialNumberData(out VMProtectSerialNumberData data, int size)
	{ assert(0); }

	extern (Windows)
	int VMProtectGetCurrentHWID(char* hwid, int size)
	{ assert(0); }

	extern (Windows)
	int VMProtectActivateLicense(const(char)* code, char* serial, int size)
	{ assert(0); }

	extern (Windows)
	int VMProtectDeactivateLicense(const(char)* serial)
	{ assert(0); }

	extern (Windows)
	int VMProtectGetOfflineActivationString(const(char)* code, char* buffer, int size)
	{ assert(0); }

	int VMProtectGetOfflineDeactivationString(const(char)* serial, char* buffer, int size)
	{ assert(0); }
}

pragma(inline, true)
{
	void VMProtectBegin(string marker = __FUNCTION__)()
	{
		VMProtectBegin(marker.ptr);
	}

	void VMProtectBeginVirtualization(string marker = __FUNCTION__)()
	{
		VMProtectBeginVirtualization(marker.ptr);
	}

	void VMProtectBeginMutation(string marker = __FUNCTION__)()
	{
		VMProtectBeginMutation(marker.ptr);
	}

	void VMProtectBeginUltra(string marker = __FUNCTION__)()
	{
		VMProtectBeginUltra(marker.ptr);
	}

	void VMProtectBeginVirtualizationLockByKey(string marker = __FUNCTION__)()
	{
		VMProtectBeginVirtualizationLockByKey(marker.ptr);
	}

	void VMProtectBeginUltraLockByKey(string marker = __FUNCTION__)()
	{
		VMProtectBeginUltraLockByKey(marker.ptr);
	}
}
