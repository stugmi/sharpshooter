module sharpshooter.vector;

import std.algorithm.comparison;
import std.math;
import std.typecons;

/// A 2-dimensional Euclidean vector
struct Vector2
{
	/// The X coordinate
	float x;

	/// The Y coordinate
	float y;

	/// Get the magnitude.
	float magnitude() const @property
	{
		return sqrt(pow(x, 2) + pow(y, 2));
	}

	/// Get the angle to another.
	float angle(Vector2 other) const
	{
		return atan2(other.y - y, other.x - x);
	}
}

/// A 3-dimensional Euclidean vector
struct Vector3
{
	/// Get the origin.
	static Vector3 origin() @property
	{
		return Vector3(0, 0, 0);
	}

	/// The X coordinate
	float x;
	
	/// The Z coordinate
	float z;

	/// The Y coordinate
	float y;

	/// Constructor
	this(float x, float y, float z)
	{
		this.x = x;
		this.y = y;
		this.z = z;
	}

	Vector3 opBinary(string op)(Vector3 other) const
	{
		return Vector3(
			mixin("x " ~ op ~ " other.x"),
			mixin("y " ~ op ~ " other.y"),
			mixin("z " ~ op ~ " other.z"),
		);
	}

	Vector3 opBinary(string op)(float operand) const
	{
		return Vector3(
			mixin("x " ~ op ~ " operand"),
			mixin("y " ~ op ~ " operand"),
			mixin("z " ~ op ~ " operand"),
		);
	}

	void opOpAssign(string op)(Vector3 other)
	{
		mixin("x " ~ op ~ "= other.x;");
		mixin("y " ~ op ~ "= other.y;");
		mixin("z " ~ op ~ "= other.z;");
	}
	
	/// Get the sum.
	float sum() const @property
	{
		return x + y + z;
	}

	/// Get the magnitude.
	float magnitude() const @property
	{
		return sqrt(pow(x, 2) + pow(y, 2) + pow(z, 2));
	}

	/// Get the yaw to another.
	float yaw(Vector3 other) const
	{
		return atan2(other.y - y, other.x - x);
	}

	/// Get the pitch to another.
	float pitch(Vector3 other) const
	{
		return ((z - other.z) / (pow(x - other.x, 2) + pow(y - other.y, 2)).sqrt).atan;
	}
}

/// Get the Euclidean distance between two vectors.
float distance(Vector2 first, Vector2 second)
{
	return sqrt(pow(second.x - first.x, 2) + pow(second.y - first.y, 2));
}

float distance(Vector3 first, Vector3 second)
{
	return sqrt(pow(second.x - first.x, 2) + pow(second.y - first.y, 2) + pow(second.z - first.z, 2));
}

/// Translate a vector.
Vector2 translate(Vector2 vector, float distance, float angle)
{
	return Vector2(
		vector.x + distance * angle.cos,
		vector.y + distance * angle.sin,
	);
}

Vector3 translate(Vector3 vector, float distance, float yaw, float pitch)
{
	return Vector3(
		yaw.cos * distance + vector.x,
		yaw.sin * distance + vector.y,
		pitch.sin * distance + vector.z,
	);
}

/// Get the difference between two angles (in radians).
T differenceBetweenAngles(T)(T first, T second)
{
	immutable TAU = PI * 2;
	auto difference = first - second;
	if (difference > PI)
	{
		difference -= TAU;
	}
	else if (difference < -PI)
	{
		difference += TAU;
	}

	return difference;
}

/// Get the position to intercept a moving object.
Nullable!Vector3 interceptPosition(Vector3 target, Vector3 targetVelocity, Vector3 interceptor, float interceptorSpeed)
{
	immutable difference = target - interceptor;
	immutable differenceSquaredSum = (difference ^^ 2).sum;

	immutable h1 = (targetVelocity ^^ 2).sum - interceptorSpeed ^^ 2;
	immutable h2 = (difference * targetVelocity).sum;

	float time = -1;
	if (h1 == 0)
	{
		time = -differenceSquaredSum / (h2 * 2);
	}
	else
	{
		immutable b = -h2 / h1;
		immutable discriminant = b ^^ 2 - differenceSquaredSum / h1;
		if (discriminant >= 0)
		{
			immutable root = discriminant.sqrt;
			immutable time1 = b + root;
			immutable time2 = b - root;

			immutable minTime = min(time1, time2);
			immutable maxTime = max(time1, time2);

			time = minTime > 0 ? minTime : maxTime;
		}
	}

	return time >= 0
		? nullable(target + targetVelocity * time)
		: Nullable!Vector3();
}

Nullable!Vector3 solveBallisticArc(
	Vector3 target,
	Vector3 targetVelocity,
	Vector3 projectile,
	float projectileSpeed,
	float gravity)
{
	import std.algorithm.mutation;
	// Math functions need Y to be the vertical axis
	swap(target.y, target.z);
	swap(targetVelocity.y, targetVelocity.z);
	swap(projectile.y, projectile.z);

	Vector3[2] solutions;
	if (!solveBallisticArc(
		projectile,
		projectileSpeed,
		target,
		targetVelocity,
		gravity,
		solutions[0],
		solutions[1]))
	{
		return Nullable!Vector3();
	}
	
	swap(solutions[0].y, solutions[0].z);
	return nullable(solutions[0]);
}

bool isZero(double d)
{
	immutable eps = 1e-9;
	return d > -eps && d < eps;
}

int solveBallisticArc(
	Vector3 proj_pos,
	float proj_speed,
	Vector3 target_pos,
	Vector3 target_velocity,
	float gravity,
	out Vector3 s0,
	out Vector3 s1)
{
	double G = gravity;

	double A = proj_pos.x;
	double B = proj_pos.y;
	double C = proj_pos.z;
	double M = target_pos.x;
	double N = target_pos.y;
	double O = target_pos.z;
	double P = target_velocity.x;
	double Q = target_velocity.y;
	double R = target_velocity.z;
	double S = proj_speed;

	double H = M - A;
	double J = O - C;
	double K = N - B;
	double L = -.5f * G;

	// Quartic Coeffecients
	double c0 = L*L;
	double c1 = 2*Q*L;
	double c2 = Q*Q + 2*K*L - S*S + P*P + R*R;
	double c3 = 2*K*Q + 2*H*P + 2*J*R;
	double c4 = K*K + H*H + J*J;

	// Solve quartic
	double[4] times;
	int numTimes = solveQuartic(c0, c1, c2, c3, c4, times[0], times[1], times[2], times[3]);

	// Sort so faster collision is found first
	import std.algorithm.sorting;
	import std.array;
	auto sortedTimes = times[].sort.array;

	// Plug quartic solutions into base equations
	// There should never be more than 2 positive, real roots.
	Vector3[2] solutions;
	int numSolutions = 0;

	for (int i = 0; i < numTimes && numSolutions < 2; ++i) {
		double t = times[i];
		if (t <= 0)
			continue;

		solutions[numSolutions].x = cast(float)((H+P*t)/t);
		solutions[numSolutions].y = cast(float)((K+Q*t-L*t*t)/ t);
		solutions[numSolutions].z = cast(float)((J+R*t)/t);
		++numSolutions;
	}

	// Write out solutions
	if (numSolutions > 0)   s0 = solutions[0];
	if (numSolutions > 1)   s1 = solutions[1];

	return numSolutions;
}

int solveQuartic(
	double c0,
	double c1,
	double c2,
	double c3,
	double c4,
	out double s0,
	out double s1,
	out double s2,
	out double s3)
{
	double[4] coeffs;
	double  z, u, v, sub;
	double  A, B, C, D;
	double  sq_A, p, q, r;
	int     num;

	/* normal form: x^4 + Ax^3 + Bx^2 + Cx + D = 0 */
	A = c1 / c0;
	B = c2 / c0;
	C = c3 / c0;
	D = c4 / c0;

	/*  substitute x = y - A/4 to eliminate cubic term: x^4 + px^2 + qx + r = 0 */
	sq_A = A * A;
	p = - 3.0/8 * sq_A + B;
	q = 1.0/8 * sq_A * A - 1.0/2 * A * B + C;
	r = - 3.0/256*sq_A*sq_A + 1.0/16*sq_A*B - 1.0/4*A*C + D;

	if (isZero(r)) {
		/* no absolute term: y(y^3 + py + q) = 0 */

		coeffs[ 3 ] = q;
		coeffs[ 2 ] = p;
		coeffs[ 1 ] = 0;
		coeffs[ 0 ] = 1;

		num = solveCubic(coeffs[0], coeffs[1], coeffs[2], coeffs[3], s0, s1, s2);
	}
	else {
		/* solve the resolvent cubic ... */
		coeffs[ 3 ] = 1.0/2 * r * p - 1.0/8 * q * q;
		coeffs[ 2 ] = - r;
		coeffs[ 1 ] = - 1.0/2 * p;
		coeffs[ 0 ] = 1;

		solveCubic(coeffs[0], coeffs[1], coeffs[2], coeffs[3], s0, s1, s2);

		/* ... and take the one real solution ... */
		z = s0;

		/* ... to build two quadric equations */
		u = z * z - r;
		v = 2 * z - p;

		if (isZero(u))
			u = 0;
		else if (u > 0)
			u = u.sqrt;
		else
			return 0;

		if (isZero(v))
			v = 0;
		else if (v > 0)
			v = v.sqrt;
		else
			return 0;

		coeffs[ 2 ] = z - u;
		coeffs[ 1 ] = q < 0 ? -v : v;
		coeffs[ 0 ] = 1;

		num = solveQuadric(coeffs[0], coeffs[1], coeffs[2], s0, s1);

		coeffs[ 2 ]= z + u;
		coeffs[ 1 ] = q < 0 ? v : -v;
		coeffs[ 0 ] = 1;

		if (num == 0) num += solveQuadric(coeffs[0], coeffs[1], coeffs[2], s0, s1);
		if (num == 1) num += solveQuadric(coeffs[0], coeffs[1], coeffs[2], s1, s2);
		if (num == 2) num += solveQuadric(coeffs[0], coeffs[1], coeffs[2], s2, s3);
	}

	/* resubstitute */
	sub = 1.0/4 * A;

	if (num > 0)    s0 -= sub;
	if (num > 1)    s1 -= sub;
	if (num > 2)    s2 -= sub;
	if (num > 3)    s3 -= sub;

	return num;
}

int solveQuadric(double c0, double c1, double c2, out double s0, out double s1)
{
	double p, q, D;

	/* normal form: x^2 + px + q = 0 */
	p = c1 / (2 * c0);
	q = c2 / c0;

	D = p * p - q;

	if (isZero(D)) {
		s0 = -p;
		return 1;
	}
	else if (D < 0) {
		return 0;
	}
	else /* if (D > 0) */ {
		double sqrt_D = D.sqrt;

		s0 =   sqrt_D - p;
		s1 = -sqrt_D - p;
		return 2;
	}
}

int solveCubic(double c0, double c1, double c2, double c3, out double s0, out double s1, out double s2)
{
	int     num;
	double  sub;
	double  A, B, C;
	double  sq_A, p, q;
	double  cb_p, D;

	/* normal form: x^3 + Ax^2 + Bx + C = 0 */
	A = c1 / c0;
	B = c2 / c0;
	C = c3 / c0;

	/*  substitute x = y - A/3 to eliminate quadric term:  x^3 +px + q = 0 */
	sq_A = A * A;
	p = 1.0/3 * (- 1.0/3 * sq_A + B);
	q = 1.0/2 * (2.0/27 * A * sq_A - 1.0/3 * A * B + C);

	/* use Cardano's formula */
	cb_p = p * p * p;
	D = q * q + cb_p;

	if (isZero(D)) {
		if (isZero(q)) /* one triple solution */ {
			s0 = 0;
			num = 1;
		}
		else /* one single and one double solution */ {
			double u = pow(-q, 1.0/3.0);
			s0 = 2 * u;
			s1 = - u;
			num = 2;
		}
	}
	else if (D < 0) /* Casus irreducibilis: three real solutions */ {
		double phi = 1.0/3 * acos(-q / sqrt(-cb_p));
		double t = 2 * sqrt(-p);

		s0 =   t * cos(phi);
		s1 = - t * cos(phi + PI / 3);
		s2 = - t * cos(phi - PI / 3);
		num = 3;
	}
	else /* one real solution */ {
		double sqrt_D = sqrt(D);
		double u = pow(sqrt_D - q, 1.0/3.0);
		double v = - pow(sqrt_D + q, 1.0/3.0);

		s0 = u + v;
		num = 1;
	}

	/* resubstitute */
	sub = 1.0/3 * A;

	if (num > 0)    s0 -= sub;
	if (num > 1)    s1 -= sub;
	if (num > 2)    s2 -= sub;

	return num;
}