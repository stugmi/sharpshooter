module sharpshooter.view;

import sharpshooter.map;
import sharpshooter.memory;
import sharpshooter.offsets;
import sharpshooter.utility;
import sharpshooter.vector;
import std.algorithm.searching;
import std.datetime;
import std.math;
import std.typecons;

/// Update the cached view data.
void updateView()
{
	updateViewProjectionMatrix;
}

/// Get the camera position. Not always correct.
Vector3 cameraPosition() @property
{
	return activePlayer ? activePlayer.headPosition : Vector3();
}

/// Get the cached view projection matrix.
ref const(float[4][4]) viewProjectionMatrix() @property
{
	return _viewProjectionMatrix;
}

/// Get the time since the view projection matrix was updated.
Duration timeSinceViewProjectionMatrixUpdate() @property
{
	return dur!"msecs"(tickCount - _lastMatrixUpdateTime);
}

/// Convert world coordinates to screen coordinates from -1 to 1.
Nullable!Vector2 worldToScreen(Vector3 position)
{
	const matrix = viewProjectionMatrix;

	immutable w
		= (matrix[0][3] * position.x)
		+ (matrix[1][3] * position.z)
		+ (matrix[2][3] * position.y)
		+ matrix[3][3];
	
	Nullable!Vector2 result;
	if (w > 0)
	{
		immutable x
			= (matrix[0][0] * position.x)
			+ (matrix[1][0] * position.z)
			+ (matrix[2][0] * position.y + matrix[3][0]);

		immutable y
			= (matrix[0][1] * position.x)
			+ (matrix[1][1] * position.z)
			+ (matrix[2][1] * position.y + matrix[3][1]);

		result = Vector2(
			x / w,
			y / w,
		);
	}

	return result;
}

private
void updateViewProjectionMatrix()
{
	immutable address1 = read!size_t(mainModule + viewProjectionMatrix1);
	immutable address2 = read!size_t(address1 + viewProjectionMatrix2);
	immutable matrix = read!(typeof(_viewProjectionMatrix))(address2 + viewProjectionMatrix3);
	if (matrix[].any!(row => row[].any!(value => value != 0.0F)))
	{
		_viewProjectionMatrix = matrix;
		_lastMatrixUpdateTime = tickCount;
	}
}

private
__gshared float[4][4] _viewProjectionMatrix;

private
__gshared ulong _lastMatrixUpdateTime;
