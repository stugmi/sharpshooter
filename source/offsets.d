module sharpshooter.offsets;

version (LDC) pragma(LDC_no_moduleinfo);

import aegis.valueencryption;

Encrypted!size_t viewProjectionMatrix1;
Encrypted!size_t viewProjectionMatrix2;
Encrypted!size_t viewProjectionMatrix3;

Encrypted!size_t mapArray;
Encrypted!size_t mapArrayKey;
Encrypted!long mapArrayKeyConstant;
immutable mapArrayLength = 0x3FFF;

Encrypted!size_t mapReferencedGlobal;
Encrypted!size_t mapIndex;
Encrypted!size_t mapPatternOffset;
Encrypted!size_t mapEntityList;
Encrypted!size_t mapEntityCount;
Encrypted!size_t mapObjectList;
Encrypted!size_t mapObjectCount;
Encrypted!size_t mapFrameRate;
Encrypted!size_t mapFrameCount;

Encrypted!size_t mapEntityIndex;
Encrypted!size_t mapEntityObjectIndex;
Encrypted!size_t mapEntityMovementData;
Encrypted!size_t mapEntityMovementDataPointer;
Encrypted!size_t mapEntityMovementDataPointerPosition;
Encrypted!size_t mapEntityMovementDataVelocity;
Encrypted!size_t mapEntitySize;

Encrypted!size_t movementDataExtraPointer;
Encrypted!size_t movementDataFeetList;
Encrypted!size_t movementDataBoundingTopZ;
Encrypted!size_t movementDataBoundingBottomZ;
Encrypted!size_t movementDataFootPosition1;
Encrypted!size_t movementDataFootPosition2;
Encrypted!size_t movementDataFootNext;

Encrypted!size_t mapObjectBoundingBottom;
Encrypted!size_t mapObjectBoundingTop;
immutable mapObjectSize = 0xC0;
Encrypted!size_t mapObjectTeam;
Encrypted!size_t mapObjectState;

pragma(inline, true)
void initializeOffsets()
{
	// Release: 48 8B 1D ? ? ? ? 0F 57 C0 F3
	// PTR: 48 8B 0D ? ? ? ? 66 0F 6E D8
	viewProjectionMatrix1 = 0x2BBA338;
	viewProjectionMatrix2 = 0x8;
	viewProjectionMatrix3 = 0x10;

	// Release: B8 FF 3F 00 00 66 3B C1 76 51 4C 8B 0D
	//     or B8 FF 3F 00 00 66 3B C1 76 50 4C
	//     or B8 FF 3F 00 00 66 3B C1 76 59
	// PTR: 48 83 EC 38 B8 FF 3F 00 00 66 3B C1 77 38 80 3D 43 ? ? ? ? 0F 85 B8
	mapArray = 0x28B6870;
	mapArrayKey = 0x282A919;
	mapArrayKeyConstant = 0x26CD5D7A7A1189AA;
	mapReferencedGlobal = 0x26A7458;

	mapIndex = 0x0;
	mapPatternOffset = 0x790;
	mapEntityList = 0x3A0; // dmPool<dmPhantom>
	mapEntityCount = 0x3B0;
	mapObjectList = 0x3B8; // dmPool<dmFixture>
	mapObjectCount = 0x3CC;
	mapFrameRate = 0x760;
	mapFrameCount = 0x7AC;

	mapEntityIndex = 0x28;
	mapEntityObjectIndex = 0x2C;
	mapEntityMovementData = 0x30; // + 2CE == 2 normally but 0 with hero select screen open
	mapEntityMovementDataPointer = 0x28;
	mapEntityMovementDataPointerPosition = 0x48;
	mapEntityMovementDataVelocity = 0x1D0;
	mapEntitySize = 0x50;

	movementDataExtraPointer = 0x258;
	movementDataFeetList = 0xF0;
	movementDataBoundingTopZ = 0x184;
	movementDataBoundingBottomZ = 0x174;
	movementDataFootPosition1 = 0x220;
	movementDataFootPosition2 = 0x10;
	movementDataFootNext = 0x68;

	mapObjectBoundingBottom = 0x0;
	mapObjectBoundingTop = 0x10;
	mapObjectTeam = 0x98;
	mapObjectState = 0x9A;
}
