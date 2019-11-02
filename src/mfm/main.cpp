#include"mfm_format.h"
#include<fstream>
#include<cstdio>

int main(int argc, char *argv[])
{
	std::ifstream f(argv[1], std::ios::binary);
	if(!f)
		return 1;

	MFMIMG header;
	f.read((char*)&header, sizeof(header));

	printf("%d, %d, %d\n", header.floppyRPM, header.number_of_track, header.number_of_side);

	unsigned totalTracks = header.number_of_track * header.number_of_side;
	MFMTRACKIMG tracksHeaders[totalTracks];
	printf("%d\n", sizeof(tracksHeaders));
	f.read((char*)tracksHeaders, sizeof(tracksHeaders));
	printf(".\n");

	//std::ofstream o("output.txt");
	std::ofstream o("output.img", std::ios::binary);

	for(int a = 0; a < totalTracks; ++a)
	{
		printf("Track: %d, Side: %d, Size: %d, Offset: %x\n", tracksHeaders[a].track_number, tracksHeaders[a].side_number, tracksHeaders[a].mfmtracksize, tracksHeaders[a].mfmtrackoffset);

		f.seekg(tracksHeaders[a].mfmtrackoffset, std::ios::beg);

		//o << "Track: " << a;// << std::endl;
		//o << "        ";

		unsigned char buffer[tracksHeaders[a].mfmtracksize];
		f.read((char*)buffer, sizeof(buffer));
		//for(unsigned b = 0; b < sizeof(buffer)/2; ++b)
		for(unsigned b = 0; b < sizeof(buffer)/2; ++b)
		{
			//char data = buffer[b];
			//unsigned short data = (buffer[b*2] << 8) | (buffer[b*2 + 1] << 0); //((unsigned short*)buffer)[b];

			//unsigned short data = ((unsigned short*)buffer)[b];
			unsigned short data = 0;

			data |= buffer[b * 2 + 0];
			data <<= 8;
			data |= buffer[b * 2 + 1];

			/*printf("X: %02x %02x\n", buffer[b * 2 + 1], buffer[b * 2 + 0]);
			printf("Test: %04x != %04x\n", data, ((unsigned short*)buffer)[b]);
			return 1;*/

			//unsigned char presData = data;
			char odata = 0;
			for(unsigned c = 0; c < 8; ++c)
			{
				odata <<= 1;
				if(data & 0x4000)
					odata |= 1;

				data <<= 2;
			}

			char tmp[] = "0123456789ABCDEF";
			//o << tmp[presData >> 4] << tmp[presData & 0x0f];
			//o << " = ";
			//o << tmp[odata];
			o.write(&odata, 1);
			//o << std::endl;
		}

		//o << std::endl;
	}

	o.close();
	f.close();
	return 0;
}
