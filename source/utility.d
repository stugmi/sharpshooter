module sharpshooter.utility;

import aegis.stringencryption;
import aegis.utility;
import core.sys.windows.windows;
import sharpshooter.imports.kernel32;
import sharpshooter.imports.user32;
import std.algorithm.iteration;
import std.array;
import std.concurrency;
import std.conv;
import std.datetime;
import std.exception;
import std.file;
import std.random;
import std.range;
import std.stdio;
import std.string;
import std.traits;
import vmprotect;

/// Get the name of a symbol.
template name(alias T)
{
	enum name = fullyQualifiedName!T[fullyQualifiedName!T.lastIndexOf('.') + 1 .. $];
}

/// A circular buffer
struct CircularBuffer(T, size_t length)
{
	ref inout(T) opIndex(size_t index) inout
	{
		return _elements[(_startIndex + index) % length];
	}

	void push(T element)
	{
		_elements[_startIndex] = element;
		_startIndex = (_startIndex + 1) % length;
	}

	ref inout(T) top() inout
	{
		return opIndex(length - 1);
	}

	ref inout(T) bottom() inout
	{
		return opIndex(0);
	}

	private
	T[length] _elements;

	private
	size_t _startIndex;
}

/// Get the module handle.
HMODULE moduleHandle()
{
	return cast(HMODULE) &__ImageBase;
}

/// Log a message to the console.
void log(string fmt, Args...)(Args args)
{
	static assert(__traits(compiles, format!fmt(args)));
	immutable time = Clock.currTime;
	immutable message = format(encrypted!"%02d:%02d:%02d: %s\r\n", time.hour, time.minute, time.second,
		format(encrypted!fmt, args));

	version (ProtectProcess)
	{
		if (logFileName is null)
		{
			immutable logsName = encrypted!"Logs";
			if (!exists(logsName))
			{
				mkdir(logsName);
			}

			logFileName = format(encrypted!"%s\\%04d-%02d-%02d %02d-%02d-%02d.txt",
				logsName, time.year, time.month, time.day, time.hour, time.minute, time.second);
		}

		append(logFileName, message);
	}
	else
	{
		write(message);
	}
}

/// Get the system time.
pragma(inline, true)
ulong systemTime() @property
{
	enum userSharedDataSystemTime = 0x7FFE0014;
	return *cast(const(ulong)*) userSharedDataSystemTime;
}

/// Get the timestamp in milliseconds.
pragma(inline, true)
ulong tickCount()
{
	immutable ulong tickCountMultiplier = *cast(const(uint)*) 0x7FFE0004;
	immutable tickCount = *cast(const(ulong)*) 0x7FFE0320;
	return tickCount * tickCountMultiplier >> 24;
}

/// Get whether the program was run from a console.
bool wasRunFromConsole() @property
{
	uint consoleProcessID;
	getWindowThreadProcessId(GetConsoleWindow, &consoleProcessID);
	return consoleProcessID != processID;
}

/// Throw an exception if check is false with the result of Windows API function function_ when called with args.
auto enforceWin32(alias function_, string check = "a", string file = __FILE__, size_t line = __LINE__, Args...)(
	Args args) @system
{
	auto a = function_(args);
	if (!mixin(check))
	{
		throwWin32Exception(encrypted!(name!function_), "", line);
	}

	return a;
}

/// Throw an exception if COM function function_ fails when called with args.
void enforceCOM(alias function_, string file = __FILE__, size_t line = __LINE__, Args...)(
	Args args) @system
{
	immutable status = function_(args);
	if (status != S_OK)
	{
		throwCOMException(encrypted!(name!function_), status, "", line);
	}
}

/// Get the English message for a Windows API error code.
string win32ErrorMessage(uint errorCode = getLastError) @trusted
{
	wchar* message;
	if (!formatMessageW(
		FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS,
		null,
		errorCode,
		MAKELANGID(LANG_ENGLISH, SUBLANG_ENGLISH_US),
		cast(wchar*) &message,
		0,
		null))
	{
		return errorCode.to!string;	
	}

	scope(exit) localFree(message);
	return message.to!string;
}

/// Generate a random string.
string generateRandomString(string characterSet = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")(
	size_t length = uniform(5, 20))
{
	return generate!(() => cast(char) characterSet[uniform(0, characterSet.length)])
		.takeExactly(length)
		.array
		.assumeUnique;
}

private
extern
extern (C)
int __ImageBase;

private
string logFileName;

private
void throwWin32Exception(string name, string file, size_t line)
{
	throw new Exception(format(encrypted!"%s failed: %s", name, win32ErrorMessage), file, line);
}

private
void throwCOMException(string name, size_t status, string file, size_t line)
{
	throw new Exception(format(encrypted!"%s failed with error code %X", name, status), file, line);
}
