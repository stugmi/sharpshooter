module sharpshooter.aimbot;

import sharpshooter.keys;
import sharpshooter.map;
import sharpshooter.player;
import sharpshooter.settings;
import sharpshooter.utility;
import sharpshooter.vector;
import sharpshooter.view;
import sharpshooter.window;
import std.algorithm.comparison;
import std.algorithm.iteration;
import std.algorithm.searching;
import std.array;
import std.datetime.stopwatch;
import std.math;
import std.random;
import std.typecons;

/// Initialize the aimbot.
void initializeAimbot()
{
	addKeyHandler(&keyHandler);
	action = Action.none;
}

/// Update the aimbot.
void updateAimbot()
{
	if (activeMap && activePlayer)
	{
		if (action != Action.none)
		{
			assert(target);

			Vector3 position;
			float within;
			switch (action) with (Action)
			{
				case lockHead:
				case flickHead:

					position = target.predictedPosition(true, true);
					within = setting!(float, "HeadRadius");
					break;
				
				case lockChest:
				case flickChest:

					position = target.predictedPosition(false, true) + Vector3(0, 0, actionZAdjust);
					within = setting!(float, "ChestRadius");
					break;

				default: assert(false);
			}

			immutable playerHeadPosition = activePlayer.headPosition;
			if (projectileActive)
			{
				if (playerHeadPosition.pitch(position).abs > 0.5 || !setting!(bool, "ProjectileHasGravity"))
				{
					immutable intercept = interceptPosition(position, target.velocity,
						playerHeadPosition, setting!(float, "ProjectileSpeed"));
					
					if (!intercept.isNull)
					{
						position = intercept.get;
					}
				}
				else
				{
					immutable firingSpeeds = solveBallisticArc(
						position,
						target.velocity,
						playerHeadPosition + Vector3(0, 0, setting!(float, "ProjectileHeight")),
						setting!(float, "ProjectileSpeed"),
						7);
					
					if (firingSpeeds.isNull)
					{
						log!"Unlocked because no ballistic arc to the target was found.";
						action = Action.none;
						return;
					}

					position = playerHeadPosition.translate(
						playerHeadPosition.distance(position),
						Vector3.origin.yaw(firingSpeeds.get),
						-Vector3.origin.pitch(firingSpeeds.get));
				}
			}

			immutable minimumLeadDistance = 5.0F;
			immutable targetDistance = position.distance(playerHeadPosition);
			/*if (targetDistance >= minimumLeadDistance)
			{
				position += target.velocity * setting!(float, "LeadSeconds");
			}*/

			if (target.speed > maximumTrackingSpeed)
			{
				action = Action.none;
				log!"Unlocked because target was moving too fast";
			}
			else
			{
				auto screen = worldToScreen(position);
				if (screen.isNull)
				{
					if (setting!(bool, "UnlockIfTargetMovesBehind"))
					{
						action = Action.none;
						log!"Target moved behind, unlocking";
						return;
					}
					else
					{
						screen = nullable(Vector2(1, 0));
					}
				}
				
				if ((action == Action.flickHead || action == Action.flickChest)
					&& (isAimedAt(position, within)
						|| actionTime.peek.total!"msecs" >= (targetIsCloseFoV
							? setting!(float, "CloseFoVAutoShootMilliseconds")
							: setting!(float, "AutoShootMilliseconds"))))
				{
					clickLeft;
					pendingFlickAction = action;
					action = Action.none;
					actionTime.reset;
					flickResetTime.stop;
					flickResetTime.reset;
					flickResetTime.start;
					return;
				}

				if (action == Action.lockHead || action == Action.lockChest)
				{
					if (setting!(bool, "FreeYAxis"))
					{
						screen.y = 0;
					}
					else if (setting!(bool, "FreeYAxisWithinBoundingBox"))
					{
						if (isAimedWithinBoundingBox(target, false, true))
						{
							screen.y = 0;
						}
						else
						{
							immutable zOffset = target.boundingHeight / 2.0F
								* setting!(float, "FreeYAxisWithinBoundingBoxFactor")
								* (screen.y > 0 ? -1 : 1);
							screen.y = (target.boundingCenter + Vector3(0, 0, zOffset)).worldToScreen.y;
						}
					}

					if (setting!(bool, "FreeXAxisWithinBoundingBox"))
					{
						if (isAimedWithinBoundingBox(target, true, false))
						{
							screen.x = 0;
						}
						else
						{
							immutable boxSide = position.translate(
								target.boundingRadius * setting!(float, "FreeXAxisWithinBoundingBoxFactor"),
								cameraPosition.yaw(position) + (screen.x > 0 ? -PI_2 : PI_2),
								0);
							screen.x = boxSide.worldToScreen.x;
						}
					}
				}
				
				immutable factor = smoothingFactor(
					screen.magnitude,
					targetDistance <= setting!(float, "CloseFoVMaximumDistance"));
				
				immutable sensitivity = setting!(uint, "Sensitivity");
				moveMouse(
					cast(int) (screen.x * factor * (2456030.0 / sensitivity)),
					cast(int) (screen.y * factor * (-1590120.0 / sensitivity)));
			}
		}
		else if (pendingFlickAction != Action.none
			&& flickResetTime.peek.total!"msecs" >= setting!(float, "FlickResetMilliseconds"))
		{
			selectTarget(true, targetIsEnemy, pendingFlickAction == Action.flickHead,
				pendingFlickAction, projectileActive);
			flickResetTime.stop;
			flickResetTime.reset;
		}

		updateBurst;
	}
}

/// Update the auto-melee.
void updateAutoMelee()
{
	if (activePlayer && setting!(bool, "AutoMelee") && isForeground)
	{
		immutable meleeDistance = 2.0F;
		auto meleeTargets = targets(true, false)
			.filter!(target => target.chestPosition.distance(activePlayer.chestPosition) < meleeDistance
				&& target.chestPosition.isAimedAt(meleeDistance))
			.array;
		
		if (meleeTargets.length)
		{
			sendKey(setting!(ushort, "MeleeKey"));
		}
	}
}

private
enum Action
{
	none,
	lockHead,
	lockChest,
	flickHead,
	flickChest,
}

private
Player target;

private
Action action;

private
Action pendingFlickAction;

private
bool targetIsEnemy;

private
StopWatch flickResetTime;

private
StopWatch actionTime;

private
StopWatch burstTime;

private
auto burstActive = false;

private
auto projectileActive = false;

private
auto targetIsCloseFoV = false;

private
float actionZAdjust;

private
void keyHandler(uint key, bool down)
{
	if (key == setting!(uint, "AimLockEnemyHeadHitScanKey"))
	{
		selectTarget(down, true, true, Action.lockHead, false);
	}
	else if (key == setting!(uint, "AimLockEnemyHeadProjectileKey"))
	{
		selectTarget(down, true, true, Action.lockHead, true);
	}
	else if (key == setting!(uint, "AimLockEnemyChestHitScanKey"))
	{
		selectTarget(down, true, false, Action.lockChest, false);
	}
	else if (key == setting!(uint, "AimLockEnemyChestProjectileKey"))
	{
		selectTarget(down, true, false, Action.lockChest, true);
	}
	else if (key == setting!(uint, "AimLockFriendHitScanKey"))
	{
		selectTarget(down, false, false, Action.lockChest, false);
	}
	else if (key == setting!(uint, "AimLockFriendProjectileKey"))
	{
		selectTarget(down, false, false, Action.lockChest, true);
	}
	else if (key == setting!(uint, "FlickShotEnemyHeadHitScanKey"))
	{
		selectTarget(down, true, false, Action.flickHead, false);
	}
	else if (key == setting!(uint, "FlickShotEnemyHeadProjectileKey"))
	{
		selectTarget(down, true, false, Action.flickHead, true);
	}
	else if (key == setting!(uint, "FlickShotEnemyChestHitScanKey"))
	{
		selectTarget(down, true, false, Action.flickChest, false);
	}
	else if (key == setting!(uint, "FlickShotEnemyChestProjectileKey"))
	{
		selectTarget(down, true, false, Action.flickChest, true);
	}
	else if (key == setting!(uint, "FlickShotFriendHitScanKey"))
	{
		selectTarget(down, false, false, Action.flickChest, false);
	}
	else if (key == setting!(uint, "FlickShotFriendProjectileKey"))
	{
		selectTarget(down, false, false, Action.flickChest, true);
	}
	else if (key == setting!(uint, "BurstKey"))
	{
		if (!down)
		{
			burstTime.stop;
			if (burstActive)
			{
				clickLeft(Click.up);
			}

			burstActive = false;
		}
		else if (!burstActive)
		{
			burstTime.reset;
			burstTime.start;
		}
	}
	else
	{
		version (ESP)
		{
			if (key == setting!(uint, "TagKey") && down && activeMap)
			{
				auto targets = activeMap.players
					.filter!(player => player != activePlayer)
					.array;
				
				if (!targets.empty)
				{
					auto target = targets.minElement!(target => target.chestPosition.positionScore);
					target.tagged = !target.tagged;
					if (target.tagged)
					{
						log!"Tagged player %d."(target.entityIndex);
					}
					else
					{
						log!"Untagged player %d."(target.entityIndex);
					}
				}
			}
		}
	}
}

private
void selectTarget(bool down, bool enemy, bool head, Action pendingAction, bool projectile)
{
	pendingFlickAction = Action.none;

	if (down)
	{
		if (action == Action.none)
		{
			target = bestTarget(enemy, head);
			if (target)
			{
				//log!"Locked on to target at %sm"(target.headPosition.distance(activePlayer.headPosition));
				action = pendingAction;
				actionTime.reset;
				actionTime.start;
				projectileActive = projectile;
				targetIsEnemy = enemy;
				targetIsCloseFoV = !target.headPosition.isWithinNormalFieldOfView;
				if (head)
				{
					actionZAdjust = 0;
				}
				else
				{
					immutable chestHeightRandomness = setting!(float, "ChestHeightRandomness");
					actionZAdjust = uniform!"[]"(-chestHeightRandomness, chestHeightRandomness);
				}
			}
			else
			{
				log!"No available target";
			}
		}
	}
	else
	{
		action = Action.none;
		if (burstTime.running)
		{
			clickLeft(Click.up);
			burstTime.stop;
		}

		burstTime.reset;
		flickResetTime.reset;
		flickResetTime.stop;
	}
}

private
Player bestTarget(bool enemy, bool head)
{
	if (activeMap && activePlayer)
	{
		auto targets = targets(enemy, head);
		return !targets.empty
			? targets.minElement!(target => (head ? target.headPosition : target.chestPosition).positionScore)
			: null;
	}

	return null;
}

private
float positionScore(Vector3 position)
{
	immutable worldDistance = activePlayer.headPosition.distance(position);
	immutable screenPosition = position.worldToScreen;
	immutable screenDistance = screenPosition.isNull ? float.infinity : screenPosition.get.magnitude;
	return screenDistance + worldDistance * setting!(float, "PositionScoreFactor");
}

private
auto targets(bool enemy, bool head) @property
{
	immutable maximumTrackingSpeed = maximumTrackingSpeed;
	return activeMap.players.filter!(player
		=> player.speed <= maximumTrackingSpeed
		&& !player.dead
		&& player.enemy == enemy
		&& player != activePlayer
		&& (head ? player.headPosition : player.chestPosition).isWithinEitherFieldOfView);
}

private
float maximumTrackingSpeed() @property
{
	return setting!(bool, "UseMaximumTrackingSpeed") ? 50.0F : float.infinity;
}

private
bool isWithinEitherFieldOfView(ref const(Vector3) position)
{
	return position.isWithinNormalFieldOfView
		|| position.isWithinCloseFieldOfView;
}

private
bool isWithinNormalFieldOfView(ref const(Vector3) position)
{
	immutable screen = worldToScreen(position);
	return !screen.isNull
		&& screen.get.magnitude <= setting!(float, "FieldOfView");
}

private
bool isWithinCloseFieldOfView(ref const(Vector3) position)
{
	immutable screen = worldToScreen(position);
	return !screen.isNull
		&& position.distance(cameraPosition) <= setting!(float, "CloseFoVMaximumDistance")
		&& screen.get.magnitude <= setting!(float, "CloseFoV");
}

private
bool isAimedAt(ref const(Vector3) position, float within)
{
	immutable screen = worldToScreen(position);
	if (screen.isNull)
	{
		return false;
	}

	immutable yaw = cameraPosition.yaw(position);
	immutable left = position.translate(within, yaw - PI_2, 0);
	immutable leftScreen = worldToScreen(left);
	if (leftScreen.isNull)
	{
		return false;
	}
	
	return screen.magnitude <= leftScreen.distance(screen);
}

private
bool isAimedWithinBoundingBox(Player target, bool xAxis, bool yAxis)
{
	assert(xAxis || yAxis);
	
	if (yAxis)
	{
		immutable position = target.boundingCenter;
		immutable height = target.boundingHeight / 2.0F * setting!(float, "FreeYAxisWithinBoundingBoxFactor");
		immutable top = (position + Vector3(0, 0, height)).worldToScreen;
		immutable bottom = (position - Vector3(0, 0, height)).worldToScreen;
		if ((!top.isNull && top.y < 0) || (!bottom.isNull && bottom.y > 0))
		{
			return false;
		}
	}

	if (xAxis)
	{
		immutable position = target.chestPosition;
		immutable yaw = cameraPosition.yaw(position);
		immutable width = target.boundingRadius * setting!(float, "FreeXAxisWithinBoundingBoxFactor");
		immutable left = position.translate(width, yaw - PI_2, 0).worldToScreen;
		immutable right = position.translate(width, yaw + PI_2, 0).worldToScreen;
		if ((!left.isNull && left.x > 0) || (!right.isNull && right.x < 0))
		{
			return false;
		}
	}

	return true;
}

private
float aimFactorWithinCircle(ref const(Vector3) position, float maximum)
{
	immutable screen = worldToScreen(position);
	if (screen.isNull)
	{
		return 1;
	}

	immutable yaw = cameraPosition.yaw(position);
	immutable left = position.translate(maximum, yaw - PI_2, 0);
	immutable leftScreen = worldToScreen(left);
	if (leftScreen.isNull)
	{
		return 1;
	}
	
	return screen.magnitude / leftScreen.distance(screen);
}

private
real smoothingFactor(float magnitude, bool close)
out (result)
{
	assert(result >= 0);
	assert(result <= 1);
}
do
{
	immutable exponent = close ? setting!(real, "CloseFoVSmoothingExponent") : setting!(real, "SmoothingExponent");
	if (exponent < 0.01)
	{
		return 1;
	}

	immutable minimumMagnitude = setting!(real, "MinimumSmoothingMagnitude");
	immutable maximumMagnitude = setting!(real, "MaximumSmoothingMagnitude");
	auto initialFactor = setting!(real, "InitialSmoothingFactor");

	initialFactor /= activeMap.frameRate;
	initialFactor *= 175;

	immutable factor = magnitude <= minimumMagnitude ? 1.0
	     : magnitude >= maximumMagnitude ? initialFactor
	     : 1.0 - (magnitude - minimumMagnitude) / (maximumMagnitude - minimumMagnitude);
	return factor.pow(exponent);
}

private
void updateBurst()
{
	if (burstTime.running)
	{
		auto search = targets(true, false).find!(target => target.isAimedWithinBoundingBox(true, true));
		if (!search.empty)
		{
			auto target = search.front;
			
			if (!burstActive)
			{
				burstActive = true;
				clickLeft(Click.down);
				burstTime.reset;
				burstTime.start;
			}
			else if (burstTime.peek.total!"msecs" / 1000.0F >= setting!(float, "BurstResetSeconds")
				&& activePlayer.position.distance(target.position) >= 12.0F)
			{
				clickLeft(Click.up);
				import core.thread;
				Thread.sleep(dur!"msecs"(25));
				clickLeft(Click.down);
				burstTime.stop;
				burstTime.reset;
				burstTime.start;
			}
		}
		else if (burstTime.running)
		{
			burstActive = false;
			clickLeft(Click.up);
			//burstTime.stop;
		}
	}
	else
	{
		burstActive = false;
	}
}
