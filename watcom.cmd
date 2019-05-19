@ECHO OFF
rem echo %1 %2 %3
set WATCOM=%4
call %WATCOM%/owsetenv.bat
@ECHO OFF
rem echo %PATH%
wcc "%1" -3 -ms -fo="%2" -fp3 -na -od -wx -zl -zls -s -bt=dos -s -w4 -zc -g=DGROUP
rem IF NOT ERRORLEVEL 0 GOTO error

rem wlink name %3 file %2 file D:\Workspace\babyOS\src\c64.obj file D:\Workspace\babyOS\src\data\font.obj sys dos com 
wlink name %3 file %2 file src\data\font.obj sys dos com op map=lst\testdos.map
rem op start=main
del %2

error: