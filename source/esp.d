module sharpshooter.esp;

import sharpshooter.map;
import sharpshooter.overlay;
import sharpshooter.player;
import sharpshooter.settings;
import sharpshooter.vector;
import sharpshooter.view;
import std.algorithm.iteration;
import std.math;

/// Update the ESP.
void updateESP()
{
	if (activePlayer && activeMap && overlayActive)
	{
		immutable showTeammates = setting!(bool, "OverlayShowTeammates");
		activeMap
			.players
			.filter!(player => player != activePlayer && !player.dead
				&& (showTeammates || player.enemy || player.spectator))
			.each!(player => player.draw);
		
		/*immutable baseAddress = activeMap.baseAddress;
		void drawList(size_t offset, size_t entrySize, size_t boxOffset)
		{
			import sharpshooter.memory;
			immutable objectList = read!size_t(baseAddress + offset);
			immutable objectCount = read!uint(baseAddress + offset + 0x10);
			for (size_t objectIndex = 0; objectIndex < objectCount; ++objectIndex)
			{
				immutable objectAddress = objectList + objectIndex * entrySize;
				draw(
					read!Vector3(objectAddress + boxOffset),
					read!Vector3(objectAddress + boxOffset + 0x10),
					Color(1, 1, 1, 1),
				);
			}
		}

		drawList(0x8, 0x40, 0); // map objects
		drawList(0x30, 0x40, 0); // entities and some other stuff
		drawList(0x58, 0x40, 0); // breakables, movables, and some larger objects
		drawList(0x80, 0x40, 0); // entities*/
	}
}

private
void draw(Vector3 boundingBottom, Vector3 boundingTop, Color color)
{
	immutable width = Vector2(boundingTop.x, boundingTop.y).distance(Vector2(boundingBottom.x, boundingBottom.y));
	
	immutable difference = boundingTop - boundingBottom;
	immutable center = boundingBottom + difference / 2.0F;

	// Draw the top
	drawLine(Vector3(boundingTop.x, boundingTop.y, boundingTop.z), Vector3(boundingBottom.x, boundingTop.y, boundingTop.z), color);
	drawLine(Vector3(boundingBottom.x, boundingTop.y, boundingTop.z), Vector3(boundingBottom.x, boundingBottom.y, boundingTop.z), color);
	drawLine(Vector3(boundingBottom.x, boundingBottom.y, boundingTop.z), Vector3(boundingTop.x, boundingBottom.y, boundingTop.z), color);
	drawLine(Vector3(boundingTop.x, boundingBottom.y, boundingTop.z), Vector3(boundingTop.x, boundingTop.y, boundingTop.z), color);
	
	// Draw the sides
	drawLine(Vector3(boundingTop.x, boundingTop.y, boundingTop.z), Vector3(boundingTop.x, boundingTop.y, boundingBottom.z), color);
	drawLine(Vector3(boundingBottom.x, boundingTop.y, boundingTop.z), Vector3(boundingBottom.x, boundingTop.y, boundingBottom.z), color);
	drawLine(Vector3(boundingBottom.x, boundingBottom.y, boundingTop.z), Vector3(boundingBottom.x, boundingBottom.y, boundingBottom.z), color);
	drawLine(Vector3(boundingTop.x, boundingBottom.y, boundingTop.z), Vector3(boundingTop.x, boundingBottom.y, boundingBottom.z), color);

	// Draw the bottom
	drawLine(Vector3(boundingTop.x, boundingTop.y, boundingBottom.z), Vector3(boundingBottom.x, boundingTop.y, boundingBottom.z), color);
	drawLine(Vector3(boundingBottom.x, boundingTop.y, boundingBottom.z), Vector3(boundingBottom.x, boundingBottom.y, boundingBottom.z), color);
	drawLine(Vector3(boundingBottom.x, boundingBottom.y, boundingBottom.z), Vector3(boundingTop.x, boundingBottom.y, boundingBottom.z), color);
	drawLine(Vector3(boundingTop.x, boundingBottom.y, boundingBottom.z), Vector3(boundingTop.x, boundingTop.y, boundingBottom.z), color);
}

private
void draw(Player player)
{
	immutable position = player.position;
	immutable boundingTop = player.boundingTop;
	immutable boundingBottom = player.boundingBottom;
	immutable width = Vector2(boundingTop.x, boundingTop.y).distance(Vector2(boundingBottom.x, boundingBottom.y));
	
	immutable bottom = Vector3(
		position.x,
		position.y,
		boundingBottom.z - 1,
	);

	immutable bottomAngle = cameraPosition.yaw(bottom);
	immutable bottomLeft = bottom.translate(width / 2, bottomAngle - PI_2, 0);
	immutable bottomRight = bottom.translate(width / 2, bottomAngle + PI_2, 0);

	immutable top = Vector3(bottom.x, bottom.y, boundingTop.z);
	immutable topAngle = cameraPosition.yaw(top);
	immutable topLeft = top.translate(width / 2, topAngle - PI_2, 0);
	immutable topRight = top.translate(width / 2, topAngle + PI_2, 0);

	immutable color = player.color;
	drawLine(bottomLeft, bottomRight, color);
	drawLine(topLeft, topRight, color);

	immutable lineLength = (top.z - bottom.z) / 8;
	drawLine(topLeft, Vector3(topLeft.x, topLeft.y, topLeft.z - lineLength), color);
	drawLine(topRight, Vector3(topRight.x, topRight.y, topRight.z - lineLength), color);
	drawLine(bottomLeft, Vector3(bottomLeft.x, bottomLeft.y, bottomLeft.z + lineLength), color);
	drawLine(bottomRight, Vector3(bottomRight.x, bottomRight.y, bottomRight.z + lineLength), color);

	if (setting!(bool, "OverlayShowHeads"))
	{
		immutable headPosition = player.headPosition;
		immutable headAngle = cameraPosition.yaw(headPosition);
		immutable radius = setting!(float, "HeadRadius");
		immutable headLeft = headPosition.translate(radius, headAngle - PI_2, 0);
		immutable headRight = headPosition.translate(radius, headAngle + PI_2, 0);
		drawLine(headLeft + Vector3(0, 0, radius), headRight + Vector3(0, 0, radius), color);
		drawLine(headLeft + Vector3(0, 0, radius), headLeft - Vector3(0, 0, radius), color);
		drawLine(headLeft - Vector3(0, 0, radius), headRight - Vector3(0, 0, radius), color);
		drawLine(headRight - Vector3(0, 0, radius), headRight + Vector3(0, 0, radius), color);
	}
}

private
Color color(const(Player) player)
{
	return player.tagged
		? Color(1, 1, 1, 1)
		: player.spectator
		? Color(0, 1, 0, 1)
		: player.enemy
		? Color(1, 0, 0, 1)
		: Color(0.106F, 0.82F, 0.914F, 1);
}
