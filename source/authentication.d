module sharpshooter.authentication;

import aegis.stringencryption;
import aegis.valueencryption;
import core.sys.windows.windows;
import sharpshooter.driver;
import sharpshooter.imports.kernel32;
import sharpshooter.utility;
import std.conv;
import std.digest.sha;
import std.exception;
import std.string;
import vmprotect;

/// The maximum time since authentication was initialized. Will cause a blue screen if exceeded.
immutable maximumAuthenticationMilliseconds = 1000 * 60 * 60 * 24 * 2;

/// Initialize authentication and authenticate.
void initializeAuthentication(string data)
{
	VMProtectBeginUltra;

	_data = data;
	_initializationSystemTime = systemTime;
	_initializationTickCount = tickCount;
	authenticate;

	VMProtectEnd;
}

/// Authenticate.
void authenticate()
{
	VMProtectBeginUltra;

	version (Authentication)
	{
		if (tickCount - _initializationTickCount > maximumAuthenticationMilliseconds)
		{
			//log!"Auth time exceeded.\nHNSecs: %s"(tickCount - _initializationTickCount);
			blueScreen;
		}

		if (_data != expectedData)
		{
			//log!"Auth failed.\nLoader passed: %s\nActual value: %s"(_data, expectedData);
			blueScreen;
		}
	}
	else
	{
		pragma(msg, "Warning: compiling without authentication. Use the Authentication version to enable it.");
	}
	
	VMProtectEnd;
}

void blueScreen()
{
	VMProtectBeginUltra;

	version (Driver)
	{
		try
		{
			setProcessID(GetCurrentProcessId, uint.max);
		}
		catch (Exception)
		{ }
		
		terminateProcess(getCurrentProcess, 0);
	}
	
	VMProtectEnd;

	assert(0);
}

private
string _data;

private
Encrypted!ulong _initializationSystemTime;

private
Encrypted!ulong _initializationTickCount;

private
string expectedData() @property
{
	VMProtectBeginUltra;
	
	auto hwid = (hddSerial ~ computerName).dup;
	encryptDecrypt(hwid);
	immutable result = sha256Of(hwid).toHexString!(LetterCase.lower).idup;

	VMProtectEnd;

	return result;
}

private
string hddSerial() @property
{
	VMProtectBeginUltra;

	uint diskSerial;
	enforceWin32!getVolumeInformationA(encrypted!"C:\\".toStringz, null, 0, &diskSerial, null, null, null, 0);

	VMProtectEnd;

	return diskSerial.to!string;
}

private
string computerName() @property
{
	VMProtectBeginUltra;

	auto name = new char[MAX_COMPUTERNAME_LENGTH + 1];
	auto size = cast(uint) name.length;
	enforceWin32!getComputerNameA(name.ptr, &size);

	VMProtectEnd;

	return name[0 .. size].assumeUnique;
}

private
void encryptDecrypt(void[] data)
{
	VMProtectBeginUltra;

	immutable keyValue = _initializationSystemTime / 10 / 1000 / 1000 / 60 / 60;
	immutable key = (cast(immutable(ubyte)*) &keyValue)[0 .. keyValue.sizeof];

	foreach (index, ref byte_; cast(ubyte[]) data)
	{
		byte_ ^= key[index % 3];
	}
	
	VMProtectEnd;
}
