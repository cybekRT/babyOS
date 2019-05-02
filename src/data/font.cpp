/*
 * zzz.cpp
 *
 *  Created on: May 2, 2019
 *      Author: cybek
 */

#include<SDL/SDL.h>
#include<SDL/SDL_ttf.h>
#include<cstdio>
#include<fstream>

#undef main
int main()
{
	setbuf(stdout, NULL);

	SDL_Init(SDL_INIT_EVERYTHING);
	TTF_Init();

	printf("Opening font\n");
	TTF_Font* font = TTF_OpenFont("font.ttf", 12);
	SDL_Color fontColor = { 255, 255, 255, 255 };

	char text[256 + 1] = {0};
	for(unsigned a = 1; a < 256; ++a)
		text[a] = a;
	text[0] = ' ';

	printf("Rendering\n");
	SDL_Surface* fontSrf = TTF_RenderText_Solid(font, text, fontColor);
	int fontWidth = fontSrf->w / 256;
	int fontHeight = fontSrf->h;
	printf("Creating surface\n");
	SDL_Surface* fontSrf8 = SDL_CreateRGBSurface(0, fontSrf->w, fontSrf->h, 8, 0xff, 0xff, 0xff, 0x000000);
	SDL_BlitSurface(fontSrf, NULL, fontSrf8, NULL);

	/*SDL_Surface* fontSrf8 = SDL_CreateRGBSurface(0, 320, 100, 10, 0xff, 0xff, 0xff, 0x000000);
	for(unsigned y = 0; y < 16; ++y)
	{
		SDL_Rect src, dst;
		src.x = y * fontWidth * 16;
		src.y = 0;
		src.w = 16 * fontWidth;
		src.h = fontHeight;

		dst.x = 0;
		dst.y = y * fontHeight;
		dst.w = src.w;
		dst.h = src.h;

		SDL_BlitSurface(fontSrf, &src, fontSrf8, &dst);
	}*/

	printf("Saving\n");
	SDL_SaveBMP(fontSrf8, "font.bmp");
	printf("Pitch: %d\n", fontSrf8->pitch);
	printf("BPP: %d\n", fontSrf8->format->BytesPerPixel);

	printf("Creating bin file\n");
	std::ofstream fontBin("font.bin", std::ios::binary);
	for(int a = 0; a < 256; ++a)
	{
		for(unsigned y = 0; y < fontHeight; y++)
		{
			int charBits = 0;
			for(unsigned x = 0; x < fontWidth; ++x)
			{
				Uint8* p = (Uint8*)fontSrf8->pixels;

				//int pos = a * fontWidth + x + y * fontSrf8->w;
				int pos = a * fontWidth + x + y * fontSrf8->pitch;

				//fontBin.write((char*)&p[pos * fontSrf8->format->BytesPerPixel], 1);

				if(p[pos * fontSrf8->format->BytesPerPixel])
					charBits |= 1 << (7-x);
			}
			fontBin.write((char*)&charBits, 1);
		}
	}
	//fontBin.write((char*)fontSrf8->pixels, fontSrf8->w * fontSrf8->h);
	fontBin.close();

	printf("Creating bin file\n");
	std::ofstream fontAsm("font.asm");
	fontAsm << "[bits 16]\n[section _DATA class=DATA]\n\n\nglobal _fontWidth\nglobal _fontHeight\nglobal _font" << "\n";
	fontAsm << "align 8\n_fontWidth: db " << std::to_string(fontWidth) << "\n";
	fontAsm << "align 8\n_fontHeight: db " << std::to_string(fontHeight) << "\n";
	fontAsm << "align 8\n_font: incbin \"font.bin\"\n";
	fontAsm.close();

	printf("Creating header file\n");
	std::ofstream fontHeader("font.h");
	fontHeader << "#include<stdint.h>\nextern uint8_t fontWidth;\nextern uint8_t fontHeight;\nextern uint8_t font[];\n" << "\n";
	fontHeader.close();

	printf("Assembling...\n");
	system("nasm -f obj font.asm -o font.obj");

	// Test
	/*{
		SDL_Surface* screen = SDL_SetVideoMode(320, 200, 8, SDL_SWSURFACE);
		if(!screen)
			return 1;

		std::ifstream f("font.bin", std::ios::binary);
		int fLen = 256 * fontWidth * fontHeight;

		char font[fLen];
		f.read(font, fLen);
		char* p = (char*)screen->pixels;

		for(unsigned a = 0; a < 256; ++a)
		{
			//int x = a % 16 * fontWidth;
			//int y = a / 16 * fontWidth;

			unsigned pitch = fontWidth * fontHeight;
			unsigned dx, dy;
			for(dy = 0; dy < fontHeight; dy++)
			{
				for(dx = 0; dx < fontWidth; ++dx)
				{
					int realX = (a % 16) * fontWidth + dx;
					int realY = (a / 16) * fontHeight + dy;
					int color;

					if(font[a * pitch + dy * fontWidth + dx] )
						color = 0x4;
					else
						color = 0x2;

					p[realY * 320 + realX] = color;
				}
			}
		}

		SDL_SaveBMP(screen, "screen.bmp");

		SDL_Flip(screen);
		SDL_Delay(2000);
	}*/

	printf("OK\n");
	TTF_Quit();
	SDL_Quit();
	return 0;
}
