@echo off
SetLocal EnableExtensions

cd /d "%~dp0" || cd /d "%~dps0"

echo *--------------------------------------------------*
echo * App crash dump collecting script by Alex Dragokas
echo *--------------------------------------------------*

if not exist "helper\procdump.exe" (
  echo You need to unpack this archive first
  echo.
  echo ��� �㦭� ᯥࢠ �ᯠ������ ��娢
  pause >NUL
  exit /b
)

if not exist "HiJackThis.exe" (
  echo You need to copy HiJackThis.exe to this folder first
  echo.
  echo ��� �㦭� ᯥࢠ ᪮��஢��� �ணࠬ�� HiJackThis.exe ^(�� ����� ...\Autologger\HiJackThis\ ^) � ��� �����
  pause >NUL
  exit /b
)

net session >NUL 2>NUL || (
  echo Run this file as Administrator !!!
  echo.
  echo ����᪠�� ��� 䠩� �ࠢ�� ������� ��� "�� ����� �����������" !!!
  pause >NUL
  exit /b
)

echo.
echo Starting ProcDump. Please wait ...

> "procdump.log" helper\procdump.exe -accepteula -ma -f "" -l -e 1 -w -x . HiJackThis.exe /silentautolog /debug

echo Parsing ...
type procdump.log | findstr /i /c:"Exception" /c:"Unhandled" /c:"Dump" | find /v /i "dump\"

echo.
echo Finalyzing file operations ...
>NUL ping 127.1 -n 5

if exist "helper\*.dmp" move "helper\*.dmp" .

>NUL copy /y HiJackThis.exe helper\Jack.exe

echo.
echo Launching HiJackThis ...
ren helper\Jack.exe _poly.exe

helper\_poly.exe /silentautolog /debug

ren helper\_poly.exe Jack.exe
del helper\Jack.exe

>NUL move /y helper\HiJackThis.log HiJackThis.poly.log
>NUL move /y helper\HiJackThis_debug.log HiJackThis_debug.poly.log

echo.
echo Making archive ...
helper\7za.exe a -ssw -mx5 -y Dumps.zip procdump.log HiJackThis*.dmp HiJackThis*.log && (del *.log)

echo.
if exist *.dmp (
  echo ���� �� ����祭 / Dump is received.
) else (
  echo ���� �� ��� ����祭 / Dump WAS NOT received.
)
echo.
echo *-------------------------------------------------------------------*
echo * ��娢 Dumps.zip �ਪ९�� � ⥬�, ��� ��� ����뢠�� ������       *
echo *-------------------------------------------------------------------*
echo * Achive Dumps.zip is to be attached in the topic where helping you *
echo --------------------------------------------------------------------*
echo.
echo ��� ��室� ������ ENTER / Press ENTER to exit.

pause >NUL