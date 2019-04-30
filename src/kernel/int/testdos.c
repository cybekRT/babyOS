void runtime()
{
	main();

	__asm
	{
		mov	ax, 0
		int	85h
	}

	for(;;)
	{
		__asm
		{
			hlt
		}
	}
}

#include<i86.h>

//#include<stdio.h>
//#include<dos.h>
//#include<time.h>

//char* xxx = "yolo";

//char __cs tmp[] = "OMG, C is working!";
char tmp[] = "OMG, C is working!";

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
	char __far *p = MK_FP(0xb800, 0x0000);
	
	/*p[0] = 'T';
	p[2] = 'e';
	p[4] = 's';
	p[6] = 't';
	p[8] = '!';*/
	
	unsigned a;
	for(a = 0; a < strlen(tmp); ++a)
	{
		p[a*2] = tmp[a];
	}
	
	/*p[0] = 'T';
	p[2] = 'e';
	p[4] = 's';
	p[6] = 't';
	p[8] = '!';*/

	//for(;;);

	//return 0;
}
