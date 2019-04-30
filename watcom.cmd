@ECHO ON
echo %1 %2 %3
set WATCOM=%4
call %WATCOM%/owsetenv.bat
@ECHO ON
wcc "%1" -3 -ms -fo="%2" -fp3 -na -od -wx -zl -zls -s -bt=dos -s -w4 -zc -g=DGROUP
wlink name %3 file %2 sys dos com 
rem op start=main
rm %2