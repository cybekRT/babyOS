#include<fstream>
#include<cstdio>
#include<string>
#include<cstdint>

int main(int argc, char *argv[])
{
	setbuf(stdout, nullptr);

	std::ifstream f(argv[1], std::ios::binary);
	if(!f)
		return 1;

	std::ofstream o(std::string("mfm_") + argv[1], std::ios::binary);
	if(!o)
		return 1;

	f.seekg(0, std::ios::end);
	unsigned totalBytes = f.tellg();
	f.seekg(0, std::ios::beg);

	//for(unsigned a = 0; a < 0x800; ++a)
	//	o.put(0x00);

	bool lastBit = 0;
	for(unsigned a = 0; a < totalBytes; ++a)
	{
		uint8_t byte = f.get();

		uint16_t mfmWord = 0;

		for(unsigned b = 0; b < 8; ++b)
		{
			mfmWord <<= 2;

			if(byte & 0x80)
			{
				//mfmWord |= 1;
				mfmWord |= 0b01;
				lastBit = 1;
			}
			else if(lastBit)
			{
				//mfmWord |= 0;
				mfmWord |= 0b00;
				lastBit = 0;
			}
			else
			{
				//mfmWord |= 2;
				mfmWord |= 0b10;
				lastBit = 0;
			}

			byte <<= 1;
		}

		uint8_t* buffer = (uint8_t*)&mfmWord;

		o.write((char*)buffer + 1, 1);
		o.write((char*)buffer + 0, 1);

		//printf("Byte: %02x, MFM: %04x\n", byte, mfmWord);
		//return 0;
	}

	o.close();
	f.close();

	printf("Finished!\n");
	return 0;
}
