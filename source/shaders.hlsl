struct VS_OUTPUT
{
	float4 pos : SV_POSITION;
	float4 col : COLOR;
};

struct VS_INPUT
{
	float4 pos : POSITION;
	float4 col : COLOR;
};

VS_OUTPUT VS(VS_INPUT input)
{
	VS_OUTPUT output;

	output.pos = input.pos;
	output.col = input.col;

	return output;
}

float4 PS(VS_OUTPUT input) : SV_TARGET
{
	return input.col;
}
