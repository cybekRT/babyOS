int main();
void __far runtime()
{
	__asm
	{
		//xchg	bx, bx
	}

	main();

	/*__asm
	{
		xchg	bx, bx

		mov	sp, bp
		pop	bp
		retf

		mov	ax, 0
		int	85h
	}

	for(;;)
	{
		__asm
		{
			hlt
		}
	}*/

	__asm
	{
		//xchg	bx, bx
	}
}

#include<i86.h>

//#include<stdio.h>
//#include<dos.h>
//#include<time.h>

//char* xxx = "yolo";

//char __cs tmp[] = "OMG, C is working!";
char tmp[] = "OMG, C is working!";

int SetVideoMode(char mode)
{
	int result = 1;

	__asm
	{
		mov	ah, 0
		mov	al, mode
		int	10h
		jnc	ok

		mov	ah, 0
		mov	al, 0
		int	10h
		x:
		mov	[result], 0
		//jmp x
		//mov	sp, bp
		//mov	ax, 0
		//ret

		ok:
	}

	return result;
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

void PrintChar_Text(char c)
{
	volatile static int cur = 0;
	/*unsigned char __far *p = MK_FP(0xb800, 0x0000);

	unsigned char z = c >> 4;
	p[cur * 2] = (z < 10) ? z + '0' : z + 'a';
	z = c & 0x0f;
	p[cur * 2 + 2] = (z < 10) ? z + '0' : z + 'a';
	//p[cur * 2 + 1] = 0x73;
	cur+=2;*/

	__asm
	{
xchg	bx, bx

		push	bx
		push	es
		push	ax

		mov	bx, 0xb800
		mov	es, bx
		mov	bx, word ptr cur
		//shl	bx, 1
		mov	al, byte ptr c
		//xchg bx, bx
		mov	byte ptr es:bx, al
		//inc	byte ptr es:[bx] 

		pop	ax
		pop	es
		pop	bx
	}

	cur += 2;
}

//int cur = 0;

void ScrollTerminal()
{
	unsigned lineWidth = (fontWidth != 0) ? 320 / fontWidth : 0;
	unsigned char __far *src = MK_FP(0xA000, 320 * fontHeight);
	unsigned char __far *dst = MK_FP(0xA000, 0x0000);
	unsigned int linesPerScreen = 200 / fontHeight;
	unsigned int a;

	for(a = 0; a < 320 * (linesPerScreen - 1) * fontHeight; a++)
	{
		dst[a] = src[a];
	}

	for(a = 0; a < 320 * fontHeight; a++)
	{
		dst[320 * fontHeight * (linesPerScreen - 1) + a] = 0;
	}

	cur -= lineWidth;
}

void PrintChar(char c)
{
	/*__asm
	{
		mov	al, [c]
		int	0xff
	}

	return;*/

	//static int cur = 0;
	static char _color = 10;

	unsigned char __far *p = MK_FP(0xa000, 0x0000);

	//unsigned pitch = fontWidth * fontHeight;
	unsigned pitch = fontHeight;
	unsigned dx, dy;
	int lineWidth = (fontWidth != 0) ? 320 / fontWidth : 0;
	//_color = 6;

	//fontWidth = 5;
	//fontHeight = 12;
	//lineWidth = (fontWidth != 0) ? 320 / fontWidth : 0;

	if(fontWidth == 0)
	{
		for(;;)
		{
			__asm
			{
				xchg bx, bx
				cli
				hlt
			}
		}
	}

	if(c == '\r')
	{
		cur -= cur % lineWidth;
		return;
	}
	else if(c == '\n')
	{
		cur -= cur % lineWidth;
		cur += lineWidth;

		//_color++;
		//_color = _color % 15 + 1;

		if(cur / lineWidth >= 200 / fontHeight)
		{
			ScrollTerminal();
		}

		return;
	}
	else if(c == '\t')
	{
		const int tabWidth = 4;
		cur -= cur % tabWidth;
		cur += tabWidth;
		return;
	}

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

	if(cur / lineWidth >= 200 / fontHeight)
	{
		ScrollTerminal();
	}

	//_color++;
	//_color = _color % 15 + 1;
}

void PrintString(char* str)
{
	while(*str)
	{
		PrintChar(*str);
		str++;
	}
}

__declspec(naked) void __interrupt PrintChar_INT(void)
{
	volatile uint8_t c = 'x';
	__asm
	{
		push	ax
		push	bx
		push	cx
		push	dx
		push	si
		push	di
		push	bp
		push	ds
		
		push	cs
		pop	ds

		//xchg	bx, bx
		mov	byte ptr c, al

		//push    0
		push	byte ptr c
		call PrintChar
		add	sp, 2
	}

	PrintChar_Text(c);

	/*__asm
	{
		mov	sp, bp
		pop	bp
		iret
	}*/

	__asm
	{
		pop	ds
		pop	bp
		pop	di
		pop	si
		pop	dx
		pop	cx
		pop	bx
		pop	ax
		iret
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

	cur = 0;
	if(!SetVideoMode(0x13))
	{
		SetVideoMode(3);
		return 1;
	}

	PrintChar_Text('T');
	PrintChar_Text('e');
	PrintChar_Text('s');
	PrintChar_Text('t');

	/*p = MK_FP(0xa000, 0x0000);
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
	}*/

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
	/*for(a = 0; a < 256; ++a)
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
	}*/

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

	PrintString("Welcome to realmode C code!\n");

	{
		uint16_t __far *ivt;
		uint16_t *code_seg;

		ivt = MK_FP(0x0000, 0x0000);
		code_seg = (void*)0;

		__asm
		{
			push	cs
			pop	[code_seg]
		}

		/*PrintNibble(0xaa);
		PrintNibble(0xaa);

		PrintNibble(((unsigned)code_seg) >> 12);
		PrintNibble(((unsigned)code_seg) >> 8);
		PrintNibble(((unsigned)code_seg) >> 4);
		PrintNibble(((unsigned)code_seg) >> 0);

		PrintNibble(0xaa);
		PrintNibble(0xaa);

		PrintNibble(((unsigned)PrintChar_INT) >> 12);
		PrintNibble(((unsigned)PrintChar_INT) >> 8);
		PrintNibble(((unsigned)PrintChar_INT) >> 4);
		PrintNibble(((unsigned)PrintChar_INT) >> 0);

		PrintNibble(0xaa);
		PrintNibble(0xaa);

		/*for(;;)
		{
			__asm
			{
				cli
				hlt
			}
		}* /

		PrintNibble(((unsigned)&ivt[255 * 2+1]) >> 12);
		PrintNibble(((unsigned)&ivt[255 * 2+1]) >> 8);
		PrintNibble(((unsigned)&ivt[255 * 2+1]) >> 4);
		PrintNibble(((unsigned)&ivt[255 * 2+1]) >> 0);

		PrintNibble(0xaa);
		PrintNibble(0xaa);*/

		ivt[255 * 2] = PrintChar_INT;
		ivt[255 * 2 + 1] = code_seg;

		/*__asm
		{
			xchg bx, bx

			mov	al, ' '
			int	0xff
			mov	al, ':'
			int	0xff
			mov	al, ')'
			int	0xff
			mov	al, ' '
			int	0xff
		}*/

		//PrintString("Now in color :)");

		return 0;
	}

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
