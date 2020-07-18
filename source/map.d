module sharpshooter.map;

import aegis.stringencryption;
import core.bitop;
import core.memory;
import sharpshooter.authentication;
import sharpshooter.memory;
import sharpshooter.offsets;
import sharpshooter.player;
import sharpshooter.utility;
import sharpshooter.vector;
import sharpshooter.view;
import std.algorithm.iteration;
import std.algorithm.searching;
import std.concurrency;
import std.datetime;
import std.exception;
import std.range;

/// The state of a map object
enum MapObjectState : ushort
{
	// Baby D.Va while still in mech is 0
	babyDVa = 0x0,

	/**
	 * The object is a player which is either dead or using one of the following:
	 *   D.Va's Boosters
	 *   Genji's Swift Strike
	 *   Moira's Fade
	 *   Reaper's Wraith Form
	 *   Sombra's Translocator
	 *   Tracer's Recall
	 *   Winston's Jump Pack
	 */
	deadOrAbility = 0x1080,

	/// The object is dead or is a Junkrat tire
	deadOrJunkratTire = 0x1081,

	/// The object is Torbjorn's turret or one of the Omnics that drive the gondolas on Rialto
	torbjornTurret = 0x1099,

	/// The object just spawned
	spawned = 0x1100,

	/// The object is a bot
	bot = 0x1498,

	/// The object is a player in the normal state
	normal = 0x1499,
}

/// A game map
class Map : MemoryObject
{
	/// The players
	Player[] players;
	
	/// The time of the last update
	ulong lastUpdateTime;
	
	/// The time of the last frame on the map
	ulong lastFrameTime;

	/// The last frame count
	uint lastFrameCount;

	/// Whether the map is pending removal.
	bool pendingRemoval;

	/// Constructor
	this(size_t baseAddress)
	{
		super(baseAddress);
		lastFrameTime = tickCount;
	}
	
	/// Get the index.
	ushort index() const @property
	{
		return field!ushort(mapIndex);
	}

	/// Get whether the map is valid.
	bool valid() const @property
	{
		immutable globalAddress = mainModule + mapReferencedGlobal;
		return field!size_t(mapPatternOffset) == globalAddress
			&& field!size_t(mapPatternOffset + size_t.sizeof + uint.sizeof) == globalAddress >> 32;
	}

	/// Get the frame-rate.
	float frameRate() const @property
	{
		return field!float(mapFrameRate);
	}

	/// Get the frame count.
	uint frameCount() const @property
	{
		return field!uint(mapFrameCount);
	}

	/// Get the active player.
	Player activePlayer() @property
	{
		auto search = players.find!(player => player.active);
		scope(exit) removePendingPlayers;
		return search.length ? search[0] : null;
	}

	/// Update the map.
	void update()
	{
		immutable objectListAddress = field!size_t(mapObjectList);
		immutable entityListAddress = field!size_t(mapEntityList);

		immutable entityCount = field!uint(mapEntityCount);
		if (entityCount > 100)
		{
			pendingRemoval = true;
			return;
		}

		if (!objectListAddress || !entityListAddress)
		{
			return;
		}

		immutable entityList = read!ubyte(entityListAddress, entityCount * mapEntitySize).assumeUnique;
		
		players.each!(player => player.pendingRemoval = true);
		for (size_t entityIndex = 0; entityIndex < entityCount; ++entityIndex)
		{
			immutable entityOffset = entityIndex * mapEntitySize;
			immutable objectIndex = *cast(const(int)*) &entityList[entityOffset + mapEntityObjectIndex];
			if (objectIndex != -1)
			{
				immutable entityAddress = entityListAddress + entityOffset;
				immutable objectAddress = objectListAddress + objectIndex * mapObjectSize;
				immutable state = read!MapObjectState(objectAddress + mapObjectState);
				if (state == MapObjectState.normal
					|| state == MapObjectState.deadOrAbility
					|| state == MapObjectState.bot
					|| state == MapObjectState.deadOrJunkratTire
					|| state == MapObjectState.torbjornTurret)
				{
					auto search = players.find!(player => player.baseAddress == objectAddress);
					if (search.length)
					{
						search[0].pendingRemoval = false;
					}
					else
					{
						auto player = new Player(objectAddress, entityAddress);
						players ~= player;
						log!"Found new player %s"(entityIndex);
					}
				}
				/*else if (state != MapObjectState.babyDVa)
				{
					log!"Unknown player %s (%X) %X"(entityIndex, objectAddress, cast(uint) state);
				}*/
			}
		}
		
		removePendingPlayers;
		lastUpdateTime = tickCount;

		immutable frameCount = frameCount;
		if (frameCount != lastFrameCount)
		{
			lastFrameCount = frameCount;
			lastFrameTime = lastUpdateTime;
		}
	}

	void removePendingPlayers()
	{
		if (players.any!(player => player.pendingRemoval))
		{
			players = players.filter!(player => !player.pendingRemoval).array;
		}
	}
}

/// All maps
__gshared Map[] maps;

/// The time of the last map list update
__gshared ulong mapListUpdateTime;

/// The active map
__gshared Map activeMap;

/// The active player
__gshared Player activePlayer;

/// Update the map list.
void updateMapList()
{
	size_t[mapArrayLength] mapAddresses;
	read(mainModule + mapArray, mapAddresses.ptr, mapAddresses.length);
	
	immutable key = read!size_t(mainModule + mapArrayKey) - mapArrayKeyConstant;
	immutable globalAddress = mainModule + mapReferencedGlobal;

	foreach (index, mapAddress; mapAddresses)
	{
		mapAddress ^= key;

		//import std.stdio;
		//writefln!"%X"(mapAddress);
		if (!mapAddress || !isReadable(mapAddress) || mapAddress % 0x10 || !(mapAddress % 0x100000000))
		{
			continue;
		}

		size_t[2] values;
		if (!tryRead(mapAddress + mapPatternOffset, values.ptr, values.length * size_t.sizeof, true))
		{
			continue;
		}

		size_t objectListAddress;
		if (!tryRead(mapAddress + mapObjectList, &objectListAddress, objectListAddress.sizeof, true))
		{
			continue;
		}

		size_t entityListAddress;
		if (!tryRead(mapAddress + mapEntityList, &entityListAddress, entityListAddress.sizeof, true))
		{
			continue;
		}

		immutable mask = 0xFFFFFFFF00000000;
		if (values[0] == globalAddress && (values[0] & mask) == (values[1] & mask))
		{
			auto search = maps.find!(map => map.baseAddress == mapAddress);
			if (!search.length)
			{
				auto map = new Map(mapAddress);
				maps ~= map;
				log!"Found new map %s"(map.index);
			}
		}
	}

	mapListUpdateTime = tickCount;
}

/// Update the active map and player.
void updateActivePlayer()
{
	if (maps.length)
	{
		auto mapSearch = maps.find!(map => map.activePlayer !is null);
		auto newActiveMap = mapSearch.length ? mapSearch[0] : null;
		if (activeMap != newActiveMap)
		{
			activeMap = newActiveMap;
			if (newActiveMap)
			{
				debug log!"Selected new active map %s"(newActiveMap.index);
			}
			else
			{
				debug log!"There is no active map.";
				activePlayer = null;
			}
		}

		if (activeMap)
		{
			try
			{
				auto players = newActiveMap.players;
				if (players.length)
				{
					auto search = players.find!(player => player.active && !player.torbjornTurret);
					if (!search.empty)
					{
						auto newActivePlayer = search[0];
						if (newActivePlayer != activePlayer)
						{
							activePlayer = newActivePlayer;
							log!"Selected new active player %s"(newActivePlayer.entityIndex);
						}

						return;
					}
				}
			}
			catch (Exception)
			{
				return;
			}
			
			if (activePlayer)
			{
				activePlayer = null;
				log!"There is no active player.";
			}
		}
	}
}
