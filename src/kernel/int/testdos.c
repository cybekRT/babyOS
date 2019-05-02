int main();
void __far runtime()
{
	main();

	__asm
	{
	//	retf

	//	mov	ax, 0
	//	int	85h
	}

	/*for(;;)
	{
		__asm
		{
			hlt
		}
	}*/
}

#include<i86.h>

//#include<stdio.h>
//#include<dos.h>
//#include<time.h>

//char* xxx = "yolo";

//char __cs tmp[] = "OMG, C is working!";
char tmp[] = "OMG, C is working!";

void SetVideoMode(char mode)
{
	__asm
	{
		mov	ah, 0
		mov	al, mode
		int	10h
	}
}

int IsKeyPressed()
{
	int result;

	__asm
	{
		mov	ax, 0x00
		int	0x83
		mov	[result], ax
	}

	return result;
}

int GetKeyPressed()
{
	int result;

	__asm
	{
		mov	ax, 0x01
		int	0x83
		mov	[result], ax
	}

	return result;
}

int strlen(char *s)
{
	int len = 0;
	while(*s)
	{
		len++;
		s++;
	}
	return len;
}

//extern char C64_Chars[];
#include"src/data/font.h"

int cur = 0;
void PrintNibble(char nibble)
{
	char __far *zzz = (char __far *)MK_FP(0xb800, 0000);

	nibble &= 0x0F;
	if(nibble >= 10)
		zzz[cur * 2] = (nibble - 10 + 'A');
	else
		zzz[cur * 2] = (nibble + '0');

	cur++;
}

void PrintChar(char c)
{
	static int cur = 0;
	static char _color = 1;

	unsigned char __far *p = MK_FP(0xa000, 0x0000);

	//unsigned pitch = fontWidth * fontHeight;
	unsigned pitch = fontHeight;
	unsigned dx, dy;
	int lineWidth = 320 / fontWidth;

	for(dy = 0; dy < fontHeight; dy++)
	{
		for(dx = 0; dx < fontWidth; ++dx)
		{
			int realX = (cur % lineWidth) * fontWidth + dx;
			int realY = (cur / lineWidth) * fontHeight + dy;
			int color;

			//if(font[c * pitch + dy * fontWidth + dx] )
			if(font[c * pitch + dy] & (1 << (7 - dx)))
				//color = 0x1;
				color = _color;
			else
				//color = 0x2;
				color = 0;

			p[realY * 320 + realX] = color;
		}
	}

	cur++;
	_color++;
	_color = _color % 15 + 1;
}

void PrintString(char* str)
{
	while(*str)
	{
		PrintChar(*str);
		str++;
	}
}

int main()
{
/*	asm
	{
		mov ax, 2
		int 0x10

		mov bx, 0xb800
		mov es, bx
		mov bx, 0
		mov es:[bx], 'x'

	}

	char __far *ptr = (char __far *)MK_FP(0xb800, 0000);
	for(int a = 0; a < 80*25; ++a)
	{
		//printf("%p\n", &ptr[a]);
		//printf("A: %d\n", a);
		ptr[a * 2] = 'x';
		//printf("P: %lp\n", &ptr[a]);
		msleep(1);
	}

	msleep(100);
	printf("Test! %d %d\n", sizeof(char*), sizeof(char __far *));*/

	//char __far *p = (char __far *)0xb8000000;// (char __far *)MK_FP(0xb800, 0);
	unsigned char __far *p;// = MK_FP(0xb800, 0x0000);
	
	/*p[0] = 'T';
	p[2] = 'e';
	p[4] = 's';
	p[6] = 't';
	p[8] = '!';*/
	
	unsigned a;
	/*for(a = 0; a < strlen(tmp); ++a)
	{
		p[a*2] = tmp[a];
	}*/
	
	/*p[0] = 'T';
	p[2] = 'e';
	p[4] = 's';
	p[6] = 't';
	p[8] = '!';*/

	//for(;;);

	PrintNibble(fontWidth >> 4);
	PrintNibble(fontWidth & 0x0F);
	PrintNibble(fontHeight >> 4);
	PrintNibble(fontHeight & 0x0F);
	PrintNibble(sizeof(int));
	PrintNibble(sizeof(unsigned));
	PrintNibble(sizeof(long));

	/*{
		unsigned a, z;
		for(z = 0; z < 0xfff; ++z)
			for(a = 0; a < 0xffff; ++a);
	}*/

	/*for(;;)
	{
		__asm { hlt }
	}*/

	SetVideoMode(0x13);
	p = MK_FP(0xa000, 0x0000);
	for(a = 0; a < 320*200; ++a)
	{
		int x = a % 320;
		//int y = a / 320;

		if(x < 255)
			p[a] = x;
		else
			p[a] = a;

		//p[a] = (a % 2 == 1) ? 1 : 2;// font[a];
		//p[a] = (font[a] >= 0x80) ? 1 : 2;
	}

	// C64
	/*for(a = 0; a < 256; ++a)
	{
		int x = a % 16 * 8;
		int y = a / 16 * 8;

		int dx, dy;
		for(dy = 0; dy < 8; dy++)
		{
			for(dx = 0; dx < 8; ++dx)
			{
				int realX = x + dx;
				int realY = y + dy;
				int color;

				if(C64_Chars[(a+256) * 8 + dy] & (1<<(7-dx)))
					color = 0xff;
				else
					color = 0x33;

				p[realY * 320 + realX] = color;
			}
		}
	}*/

	// TTF
	for(a = 0; a < 256; ++a)
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
					color = 0x1;
				else
					color = 0x2;

				p[realY * 320 + realX] = color;
			}
		}
	}

	//fontWidth = 5;
	//fontHeight = 10;
	/*for(a = 0; a < 8; ++a)
	{
		int x = 0;
		int y = 0;
		
		for(y = 0; y < fontHeight; ++y)
		{
			for(x = 0; x < fontWidth; ++x)
			{
				int realX = x;
				int realY = a * fontHeight + y;
				int color;

				int pitch = fontHeight * fontWidth;
				char* currentChar = &font['A'];
				if(currentChar[y * fontWidth + x] )
					color = 0x1;
				else
					color = 0x2;

				p[realY * 320 + realX] = color;
			}
		}
	}*/

	/*{
		unsigned z;
		for(z = 0; z < 0xfff; ++z)
			for(a = 0; a < 0xffff; ++a);
	}*/

	PrintString("Welcome to realmode C code!");

	for(;;)
	{
		__asm
		{
			sti
			hlt
		}

		if(IsKeyPressed())
		{
			GetKeyPressed();
			PrintString("YoLo");
		}
	}

	//SetVideoMode(3);

	return 0;
}
