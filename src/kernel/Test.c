int _main()
{
	char* ptr = (char*)0xa0000;
	
	for(unsigned a = 0; a < 320*200; a++)
	{
		ptr[a] = 0;
	}
	
	for(unsigned a = 0; a < 320; a++)
	{
		ptr[a + 320 * 0] = 0x10;
		ptr[a + 320 * 1] = 0x10;
		ptr[a + 320 * 2] = 0x10;
		
		ptr[a + 320 * 199] = 0x10;
		ptr[a + 320 * 198] = 0x10;
		ptr[a + 320 * 197] = 0x10;
	}
	
	for(;;);
	
	return 0;
}
