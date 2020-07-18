module sharpshooter.keys;

import aegis.stringencryption;
import sharpshooter.imports.user32;
import sharpshooter.utility;
import sharpshooter.window;
import std.algorithm.iteration;

/// A key handler
alias KeyHandler = void function(uint key, bool down);

/// Add a key handler.
void addKeyHandler(KeyHandler handler)
{
	keyHandlers ~= handler;
}

/// Update the key state.
void updateKeyState()
{
	for (ubyte index = 0; index < ubyte.max; ++index)
	{
		immutable state = getKeyState(index) < 0;
		if (state != keyState[index])
		{
			keyState[index] = state;
			if (!state || isForeground)
			{
				keyHandlers.each!(handler => handler(index, state));
			}
		}
	}
}

private
__gshared KeyHandler[] keyHandlers;

private
__gshared bool[ubyte.max] keyState;
