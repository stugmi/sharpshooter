module sharpshooter.player;

import aegis.stringencryption;
import sharpshooter.map;
import sharpshooter.memory;
import sharpshooter.offsets;
import sharpshooter.settings;
import sharpshooter.utility;
import sharpshooter.vector;
import sharpshooter.view;
import std.algorithm.iteration;
import std.algorithm.searching;
import std.array;
import std.datetime;
import std.math;

/// A team ID
enum Team : ubyte
{
	spectator  = 0x02,
	team1      = 0x08,
	team2      = 0x10,
	freeForAll = 0x18,
}

/// A player's position and velocity at a moment
struct PositionVelocityMoment
{
	Vector3 headPosition;
	Vector3 chestPosition;
	Vector3 velocity;
	ulong tickCount;
}

/// A player
final class Player : MemoryObject
{
	/// The position
	Vector3 position;
	
	/// The head position
	Vector3 headPosition;

	/// The chest position
	Vector3 chestPosition;

	/// The bottom corner of the bounding box
	Vector3 boundingBottom;

	/// The top corner of the bounding box
	Vector3 boundingTop;

	/// The team
	Team team;
	
	/// The state
	MapObjectState state;

	/// The entity data address
	size_t entityAddress;

	/// Whether pending removal
	bool pendingRemoval;

	/// Whether tagged
	bool tagged;

	/// Constructor
	this(size_t baseAddress, size_t entityAddress)
	{
		super(baseAddress);
		this.entityAddress = entityAddress;
	}

	/// Get the horizontal radius of the bounding box.
	float boundingRadius() const @property
	{
		return Vector2(boundingTop.x, boundingTop.y).distance(Vector2(boundingBottom.x, boundingBottom.y)) / 2.0F;
	}

	/// Get the height of the bounding box.
	float boundingHeight() const @property
	{
		return boundingTop.z - boundingBottom.z;
	}

	/// Get the center of the bounding box.
	Vector3 boundingCenter() const @property
	{
		return position + Vector3(0, 0, boundingHeight / 2.0F);
	}

	/// Get the entity index.
	uint entityIndex() const @property
	{
		return read!uint(entityAddress + mapEntityIndex);
	}

	/// Get whether the player is the active player.
	bool active() @property
	{
		try
		{
			return cast(bool) read!ulong(
				read!size_t(read!size_t(entityAddress + mapEntityMovementData)
				+ mapEntityMovementDataPointer) + mapEntityMovementDataPointerPosition);
		}
		catch (Exception)
		{
			pendingRemoval = true;
			return false;
		}
	}

	/// Get the velocity vector.
	Vector3 velocity() @property
	{
		import std.algorithm.sorting;
		return _velocities[]
			.sort!((left, right) => left.magnitude < right.magnitude)
			[_velocities.length / 2];
	}

	/// Get the speed.
	float speed() @property
	{
		immutable velocity = velocity;
		return velocity.x.abs + velocity.y.abs + velocity.z.abs;
	}

	/// Get whether dead.
	bool dead() @property
	{
		return (state == MapObjectState.deadOrAbility || state == MapObjectState.deadOrJunkratTire) && speed < 0.1;
	}

	/// Get whether an enemy.
	bool enemy() const @property
	{
		return activePlayer.team != team || team == Team.freeForAll;
	}

	/// Get whether a spectator.
	bool spectator() const @property
	{
		return team == Team.spectator;
	}

	/// Get whether a Torbjorn turret.
	bool torbjornTurret() const @property
	{
		return state == MapObjectState.torbjornTurret;
	}

	/// Get the predicted position.
	Vector3 predictedPosition(bool head, bool reaction) @property
	{
		immutable positionVelocityMoment = reaction
			? positionVelocityMomentWithReaction(setting!(uint, "ReactionMilliseconds"))
			: currentPositionVelocityMoment;
		
		immutable position = head ? positionVelocityMoment.headPosition : positionVelocityMoment.chestPosition;
		immutable secondsSinceMoment = (tickCount - positionVelocityMoment.tickCount) / 1000.0F;
		return position + positionVelocityMoment.velocity * (setting!(float, "LeadSeconds") + secondsSinceMoment);
	}

	/// Get the current position velocity moment.
	PositionVelocityMoment currentPositionVelocityMoment() @property
	{
		return PositionVelocityMoment(headPosition, chestPosition, velocity, tickCount);
	}

	/// Get the position velocity moment for a reaction time.
	PositionVelocityMoment positionVelocityMomentWithReaction(ulong reactionMilliseconds)
	{
		immutable earliestTickCount = tickCount - reactionMilliseconds;
		foreach (index; 0 .. positionVelocityMomentCount)
		{
			immutable positionVelocityMoment = _positionVelocityMoments[index];
			if (positionVelocityMoment.tickCount >= earliestTickCount)
			{
				return positionVelocityMoment;
			}
		}

		return currentPositionVelocityMoment;
	}

	/// Begin a frame.
	void beginFrame()
	{
		immutable buffer = field!(ubyte[mapObjectSize])(0);

		T get(T)(size_t offset)
		{
			return *cast(const(T)*) &buffer[offset];
		}

		team = get!Team(mapObjectTeam);
		state = get!MapObjectState(mapObjectState);
		
		boundingBottom = get!Vector3(mapObjectBoundingBottom);
		boundingTop = get!Vector3(mapObjectBoundingTop);

		position = Vector3(
			(boundingBottom.x + boundingTop.x) / 2,
			(boundingBottom.y + boundingTop.y) / 2,
			boundingBottom.z);

		immutable velocity = currentVelocity;
		_velocities[_nextVelocityIndex] = velocity;
		_nextVelocityIndex = (_nextVelocityIndex + 1) % _velocities.length;

		headPosition = Vector3(position.x, position.y, boundingTop.z + setting!(float, "HeadShotHeight"));
		chestPosition = Vector3(position.x, position.y, boundingTop.z + setting!(float, "ChestShotHeight"));

		_positionVelocityMoments.push(currentPositionVelocityMoment);
	}
	
	/// End a frame.
	void endFrame()
	{
		immutable timestamp = tickCount;
		if (timestamp - _previousPositionTime >= 100)
		{
			_previousPosition = position;
			_previousPositionTime = _previousPositionTime;
		}
	}

	/// Get whether the player contains a position.
	bool contains(ref const(Vector3) position)
	{
		return boundingTop.x >= position.x
		    && boundingTop.y >= position.y
		    && boundingTop.z >= position.z
		    && boundingBottom.x <= position.x
		    && boundingBottom.y <= position.y
		    && boundingBottom.z <= position.z;
	}

	/// Get the height.
	float height() const @property
	{
		return setting!(float, "HeadShotHeight");
	}

	private
	enum positionVelocityMomentCount = 300;

	private
	Vector3 _previousPosition;

	private
	ulong _previousPositionTime;

	private
	Vector3[5] _velocities;

	private
	ubyte _nextVelocityIndex;

	private
	ulong _lastMoveTime;

	private
	CircularBuffer!(PositionVelocityMoment, positionVelocityMomentCount) _positionVelocityMoments;

	private
	Vector3 currentVelocity() const @property
	{
		try
		{
			return read!Vector3(read!size_t(entityAddress + mapEntityMovementData) + mapEntityMovementDataVelocity);
		}
		catch (Exception)
		{
			return Vector3.origin;
		}
	}
}
