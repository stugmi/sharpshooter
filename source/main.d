module sharpshooter.main;

import aegis.stringencryption;
import aegis.utility;
import core.runtime;
import core.stdc.string;
import core.sys.windows.windows;
import core.thread;
import core.time;
import sharpshooter.aimbot;
import sharpshooter.authentication;
import sharpshooter.driver;
import sharpshooter.esp;
import sharpshooter.imports.kernel32;
import sharpshooter.imports.shell32;
import sharpshooter.imports.user32;
import sharpshooter.keys;
import sharpshooter.map;
import sharpshooter.memory;
import sharpshooter.offsets;
import sharpshooter.overlay;
import sharpshooter.settings;
import sharpshooter.threadcontextfix;
import sharpshooter.utility;
import sharpshooter.view;
import sharpshooter.window;
import std.algorithm.iteration;
import std.algorithm.searching;
import std.array;
import std.conv;
import std.datetime;
import std.stdio;
import std.string;
import std.utf;
import vmprotect;

version (Console)
{
	void main(string[] args)
	{
		run(args);
	}
}
else
{
	extern (Windows)
	int EntryPoint(HINSTANCE, HINSTANCE, char* arguments, int)
	{
		Runtime.initialize;
		
		int argCount;
		auto argsW = CommandLineToArgvW(arguments[0 .. strlen(arguments)].toUTF16z, &argCount)[0 .. argCount];
		auto args = argsW.map!(argW => argW.to!string).array;
		LocalFree(argsW.ptr);
		run(args);
		return 0;
	}
}

private
void run(string[] args)
{
	VMProtectBeginUltra;

	try
	{
		version (Driver)
		{
			//hookGetThreadContext;
			openDeviceHandle;

			version (ProtectProcess)
			{
				registerCallback;
			}
			else
			{
				pragma(msg, "Warning: compiling without process protection. Use the ProtectProcess version to enable it.");
			}
		}

		version (Authentication)
		{
			initializeAuthentication(args.length >= 2 ? args[0] : "");
			setCurrentDirectoryA(args[1].toStringz);
		}

		initializeSettings;
		loadSettings;
		
		addKeyHandler(&reloadSettings);

		log!"Waiting for game client.";
		while (!gameWindow || !active)
		{
			Thread.sleep(dur!"msecs"(50));
		}

		uint processID;
		getWindowThreadProcessId(gameWindow, &processID);
		attach(processID);
		log!"Attached to process with ID %s."(processID);
		
		initializeOffsets;
		initializeAimbot;

		auto lastUpdateTime = tickCount;
		immutable noMapUpdateMilliseconds = 500;
		while (GetKeyState(setting!(uint, "ExitKey")) >= 0 && active)
		{
			MSG message;
			while (peekMessageA(&message, null, 0, 0, PM_REMOVE))
			{
				translateMessage(&message);
				dispatchMessageA(&message);
			}
			
			if (!activeMap || activeMap.lastFrameCount != activeMap.frameCount)
			{
				update;
				authenticate;
			}

			workerUpdate;
			Thread.sleep(dur!"msecs"(1));
		}

		log!"Exiting.";
	}
	catch (Throwable exception)
	{
		immutable message = format(
			encrypted!"Fatal exception: %s\nLast error code: %d\nFull error: %s",
			exception.message,
			GetLastError,
			exception.toString);
		
		messageBoxA(null, message.toStringz, encrypted!"Sharpshooter - Error".toStringz, MB_OK);
		log!"%s"(message);
	}

	version (ProtectProcess)
	{	
		version (Driver)
		{
			try
			{
				unregisterCallback;
			}
			catch (Throwable)
			{ }
		}
	}
	else
	{
		if (!wasRunFromConsole)
		{
			getchar;
		}
	}
	
	VMProtectEnd;
}

private
pragma(inline, false)
void update()
{
	try
	{
		updateView;
		foreach (map; maps)
		{
			foreach (player; map.players)
			{
				try
				{
					player.beginFrame;
				}
				catch (Exception exception)
				{
					debug log!"%s"(exception.toString);
					player.pendingRemoval = true;
				}
			}

			if (map.players.any!(player => player.pendingRemoval))
			{
				map.players = map.players.filter!(player => !player.pendingRemoval).array;
			}
		}

		updateKeyState;
		updateAimbot;
		updateAutoMelee;
		version (ESP)
		{
			updateOverlay;
			if (overlayVisible)
			{
				updateESP;
			}
		}

		maps.each!(map => map.players.each!(player => player.endFrame));
	}
	catch (Exception exception)
	{
		if (!exception.message.canFind(encrypted!"ReadProcessMemory"))
		{
			log!"Exception while updating: %s\nFull error: %s"(exception.message, exception.toString);
		}
	}
}

private
pragma(inline, false)
void workerUpdate()
{
	try
	{
		immutable mapListUpdateFrequency = setting!(uint, "MapListUpdateFrequency");
		if ((!activeMap || tickCount - activeMap.lastFrameTime >= mapListUpdateFrequency)
			&& tickCount - mapListUpdateTime >= mapListUpdateFrequency)
		{
			updateMapList;
		}

		foreach (map; maps)
		{
			try
			{
				map.update;
			}
			catch (Exception exception)
			{
				debug log!"%s"(exception.toString);
				map.pendingRemoval = true;
			}
		}

		if (maps.any!(map => map.pendingRemoval))
		{
			maps = maps.filter!(map => !map.pendingRemoval).array;
		}

		updateActivePlayer;
	}
	catch (Exception exception)
	{
		if (!exception.message.canFind(encrypted!"failed: 299"))
		{
			log!"Exception in worker update: %s\nFull error: %s"(exception.message, exception.toString);
		}
	}
}

private
void reloadSettings(uint key, bool down)
{
	if (down && key == setting!(uint, "ReloadSettingsKey"))
	{
		loadSettings;
		log!"Reloaded settings.";
	}
}

private
uint originalProcessID;
