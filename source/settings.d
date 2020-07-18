module sharpshooter.settings;

import aegis.stringencryption;
import sharpshooter.keys;
import sharpshooter.utility;
import std.algorithm.iteration;
import std.algorithm.sorting;
import std.array;
import std.conv;
import std.exception;
import std.file;
import std.format;
import std.traits;
import toml;

/// Initialize settings.
void initializeSettings()
{
	addKeyHandler(&keyHandler);
}

/// Load settings.
void loadSettings()
{
	immutable fileName = encrypted!"settings.toml";

	if (!exists(fileName))
	{
		std.file.write(fileName, encrypted!(import("default_settings.toml")));
	}

	document = parseTOML(readText(fileName));
}

/// Get a setting by name.
T setting(T, string name)()
{
	static __gshared string decryptedName;
	if (decryptedName is null)
	{
		decryptedName = encrypted!name;
	}

	return setting!T(decryptedName);
}

private
T setting(T)(string name)
{
	TOMLValue value;
	auto found = false;

	if (const profileName = profile)
	{
		auto profilePointer = profileName in document;
		enforce(profilePointer, encrypted!"The active profile was not found.");
		if (auto valuePointer = name in profilePointer.table)
		{
			value = *valuePointer;
			found = true;
		}
	}

	if (!found)
	{
		auto valuePointer = name in document;
		enforce(valuePointer, format(encrypted!"The setting was not found: %s", name));
		value = *valuePointer;
	}

	static if (isSomeString!T)
	{
		if (value.type != TOML_TYPE.STRING)
		{
			throw new Exception(format(encrypted!"Expected a string value for setting: %s", name));
		}
		
		return value.str.to!T;
	}
	else static if (isIntegral!T)
	{
		switch (value.type) with (TOML_TYPE)
		{
			case FLOAT:   return cast(T) value.floating;
			case INTEGER: return cast(T) value.integer;
			default: throw new Exception(format(encrypted!"Expected an integer value for setting: %s", name));
		}
	}
	else static if (isFloatingPoint!T)
	{
		switch (value.type) with (TOML_TYPE)
		{
			case FLOAT:   return cast(T) value.floating;
			case INTEGER: return cast(T) value.integer;
			default: throw new Exception(format(encrypted!"Expected a floating point value for setting: %s", name));
		}
	}
	else static if (is(T == bool))
	{
		switch (value.type) with (TOML_TYPE)
		{
			case TRUE:  return true;
			case FALSE: return false;
			default: throw new Exception(format(encrypted!"Expected true or false for setting: %s", name));
		}
	}
	else
	{
		static assert(false);
	}
}

private
__gshared TOMLDocument document;

private
__gshared string profile;

private
void keyHandler(uint key, bool down)
{
	if (down)
	{
		if (key == setting!(uint, "NextProfileKey"))
		{
			selectProfile(true);
		}
		else if (key == setting!(uint, "PreviousProfileKey"))
		{
			selectProfile(false);
		}
		else
		{
			foreach (name; profiles)
			{
				const selectKeyPointer = encrypted!"SelectKey" in document[name];
				if (selectKeyPointer && selectKeyPointer.integer == key)
				{
					profile = name;
					log!"Selected profile %s."(profile);
					break;
				}
			}
		}
	}
}

private
string[] profiles() @property
{
	return document
		.byKeyValue
		.filter!(pair => pair.value.type == TOML_TYPE.TABLE)
		.array
		.sort!((left, right) => left.key < right.key)
		.map!(pair => pair.key)
		.array;
}

private
size_t indexOf(Range, T)(Range range, T value)
{
	foreach (index, currentValue; range)
	{
		if (currentValue == value)
		{
			return index;
		}
	}

	return -1;
}

private
void selectProfile(bool next)
{
	auto profiles = profiles;
	if (!profiles.length)
	{
		log!"There are no profiles.";
	}
	else
	{
		auto index = profiles.indexOf(profile);
		if (index == -1)
		{
			index = 0;
		}
		else
		{
			immutable newIndex = cast(ptrdiff_t) (index + (next ? 1 : -1));
			if (newIndex == profiles.length)
			{
				index = 0;
			}
			else if (newIndex < 0)
			{
				index = profiles.length - 1;
			}
			else
			{
				index = newIndex;
			}
		}

		profile = profiles[index];
		log!"Selected profile %s."(profile);
	}
}
