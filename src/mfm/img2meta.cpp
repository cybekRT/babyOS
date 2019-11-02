#include<fstream>
#include<cstdio>
#include<string>
#include<cstdint>

uint16_t crc = 0;
uint8_t crcTable[32];

unsigned short GenCRC16TableEntry( const unsigned short index, const short NumBits, const unsigned short Poly )
{
	int i;
	unsigned short Ret;

	// Prepare the initial setup of the register so the index is at the
	// top most bits.
	Ret = index;
	Ret <<= 16 - NumBits;

	for( i = 0; i < NumBits; i++ ) {
		if( Ret & 0x8000 )
			Ret = (Ret << 1) ^ Poly;
		else
			Ret = Ret << 1;
	}

	return Ret;
}

void InitCRCTable()
{
	unsigned short i, Count, te;
	#define NUM_BITS 4			// Width of message chunk each iteration of the CRC algorithm

	// Setup the values to compute the table
	Count = 1 << NUM_BITS;		// Number of entries in the table

	for( i = 0; i < Count; i++ )
	{
		te = GenCRC16TableEntry( i, NUM_BITS, 0x1021 );
		crcTable[i+Count]=te>>8;
		crcTable[i]=te&0xFF;
	}
}

void ResetCRC()
{
	crc = (uint16_t)-1;
}

void CRC16_Update4Bits(unsigned char *CRC16_High, unsigned char *CRC16_Low, unsigned char val ,unsigned char * crctable )
{
	unsigned char	t;

	// Step one, extract the Most significant 4 bits of the CRC register
	t = *CRC16_High >> 4;

	// XOR in the Message Data into the extracted bits
	t = t ^ val;

	// Shift the CRC Register left 4 bits
	//printf("Assign!\n");
	*CRC16_High = (*CRC16_High << 4) | (*CRC16_Low >> 4);
	*CRC16_Low = *CRC16_Low << 4;

	//printf("T: %d, T+16: %d\n", t, t+16);

	// Do the table lookups and XOR the result into the CRC Tables
	*CRC16_High = *CRC16_High ^ crctable[t+16];
	*CRC16_Low = *CRC16_Low ^ crctable[t];
}

void UpdateCRC(uint8_t byte)
{
	unsigned char *CRC16_High = (unsigned char *)&crc;
	unsigned char *CRC16_Low = CRC16_High + 1;

	CRC16_Update4Bits(CRC16_High, CRC16_Low, (unsigned char)(byte >> 4), crcTable);		// High nibble first
	CRC16_Update4Bits(CRC16_High, CRC16_Low, (unsigned char)(byte & 0x0F), crcTable);	// Low nibble
}

void WriteCRC(std::ofstream &o)
{
	o.put(crc & 0xff);
	o.put(crc >> 8);
}

void PutByte(std::ofstream &o, uint8_t byte)
{
	o.put(byte);

	UpdateCRC(byte);
}

void WritePreIndexGap(std::ofstream &o)
{
	for(unsigned a = 0; a < 80; ++a)
		o.put(0x4e);
	for(unsigned a = 0; a < 12; ++a)
		o.put(0x00);
	for(unsigned a = 0; a < 3; ++a)
		o.put(0xc2);

	o.put(0xfc);
}

void WritePostIndexGap(std::ofstream &o)
{
	for(unsigned a = 0; a < 50; ++a)
		o.put(0x4e);
	for(unsigned a = 0; a < 12; ++a)
		o.put(0x00);

	ResetCRC();

	for(unsigned a = 0; a < 3; ++a)
		PutByte(o, 0xa1);
}

void WriteIDRecord(std::ofstream &o, unsigned track, unsigned head, unsigned sector)
{
	PutByte(o, 0xfe);
	PutByte(o, track & 0xff);
	PutByte(o, head & 0xff);
	PutByte(o, sector & 0xff);
	PutByte(o, 0x02); // sector size log2(size)-7
	WriteCRC(o);
}

void WriteIDGap(std::ofstream &o)
{
	for(unsigned a = 0; a < 22; ++a)
		o.put(0x4e);
	for(unsigned a = 0; a < 12; ++a)
		o.put(0x00);

	ResetCRC();

	for(unsigned a = 0; a < 3; ++a)
		PutByte(o, 0xa1);
}

void WriteData(std::ofstream &o, uint8_t* buffer)
{
	PutByte(o, 0xfb);

	for(unsigned a = 0; a < 512; ++a)
	{
		PutByte(o, buffer[a]);
	}

	WriteCRC(o);
}

void WriteInterSectorGap(std::ofstream &o)
{
	// Inter sector gap
	for(unsigned a = 0; a < 30; ++a)
		o.put(0x4e);
}

void WriteDataGap(std::ofstream &o)
{
	for(unsigned a = 0; a < 54; ++a)
		o.put(0x4e);
	for(unsigned a = 0; a < 12; ++a)
		o.put(0x00);

	ResetCRC();

	for(unsigned a = 0; a < 3; ++a)
		PutByte(o, 0xa1);
}

void WriteTrackEnd(std::ofstream &o)
{
	for(unsigned a = 0; a < 652 - 56; ++a)
		o.put(0x4e);
}

int main(int argc, char *argv[])
{
	setbuf(stdout, nullptr);

	std::ifstream f(argv[1], std::ios::binary);
	if(!f)
		return 1;

	InitCRCTable();

	std::ofstream o(std::string("meta_") + argv[1], std::ios::binary);
	if(!o)
		return 1;

	f.seekg(0, std::ios::end);
	unsigned totalSectors = f.tellg() / 512;
	f.seekg(0, std::ios::beg);

	unsigned sectorsPerTrack = 18;

	unsigned currentSector = 1;
	unsigned currentTrack = 0;
	unsigned currentHead = 0;

	for(unsigned a = 0; a < totalSectors; ++a)
	{
		if(currentSector == 1)
		{
			WritePreIndexGap(o);
			WritePostIndexGap(o);
		}

		WriteIDRecord(o, currentTrack, currentHead, currentSector + 1);
		WriteIDGap(o);

		uint8_t buffer[512];
		f.read((char*)buffer, 512);
		WriteData(o, buffer);

		if(currentSector == sectorsPerTrack)
		{
			WriteTrackEnd(o);

			currentSector = 0;
			currentHead ^= 1;

			if(currentHead == 0)
				currentTrack++;
		}
		else
		{
			WriteInterSectorGap(o);
			WriteDataGap(o);
		}

		currentSector++;
	}

	o.close();
	f.close();

	printf("Finished!\n");
	return 0;
}
