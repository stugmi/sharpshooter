module sharpshooter.window;

import aegis.stringencryption;
import sharpshooter.driver;
import sharpshooter.imports.user32;
import sharpshooter.settings;
import sharpshooter.utility;
import core.sys.windows.windows;
import std.exception;
import std.string;
import vmprotect;

/// Get the game window handle.
HWND gameWindow() @property
{
	static HWND cachedHandle;
	if (!cachedHandle)
	{
		cachedHandle = findWindowA(encrypted!"TankWindowClass".toStringz, null);
	}

	return cachedHandle;
}

/// Get whether the game is active.
bool active() @property
{
	return cast(bool) isWindowVisible(gameWindow);
}

/// Get whether the game is in the foreground.
bool isForeground() @property
{
	return GetForegroundWindow == gameWindow;
}

/// Move the mouse relative to its current position.
void moveMouse(int x, int y)
{
	if (x || y)
	{
		version (Driver)
		{
			if (!setting!(bool, "UseOldMouseMethod"))
			{
				MouseInputData input;
				input.lastX = x;
				input.lastY = y;
				mouseInput(input);
				return;
			}
		}
		
		INPUT input;
		input.type = INPUT_MOUSE;
		input.mi.dx = x;
		input.mi.dy = y;
		input.mi.dwFlags = MOUSEEVENTF_MOVE;
		sendInput(1, &input, cast(int) input.sizeof);
	}
}

enum Click
{
	up,
	down,
	both,
}

/// Click the left mouse button.
void clickLeft(Click click = Click.both)
{
	if (click == Click.both)
	{
		clickLeft(Click.down);
		clickLeft(Click.up);
	}
	else
	{
		version (Driver)
		{
			if (!setting!(bool, "UseOldMouseMethod"))
			{
				MouseInputData input;
				input.buttonFlags = click == Click.down ? 1 : 2;
				mouseInput(input);
				return;
			}
		}
		
		INPUT input;
		input.type = INPUT_MOUSE;
		input.mi.dwFlags = click == Click.down ? MOUSEEVENTF_LEFTDOWN : MOUSEEVENTF_LEFTUP;
		sendInput(1, &input, cast(int) input.sizeof);
	}
}

/// Send a keyboard button.
void sendKey(ushort keyCode)
{
	INPUT input;
	input.type = INPUT_KEYBOARD;
	input.ki.wVk = keyCode;
	sendInput(1, &input, cast(int) input.sizeof);
	input.ki.dwFlags = KEYEVENTF_KEYUP;
	sendInput(1, &input, cast(int) input.sizeof);
}
