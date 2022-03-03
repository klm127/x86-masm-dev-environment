@echo off

:: get command line argument 1

set targ=%1

:: check if the file doesn't exist, print an error if that's the case and end program

if not exist asm\\%targ%.asm (
@echo on
  echo asm\%targ%.asm DOESNT EXIST!
  goto:EOF
)

:: create the .obj file in intermediate folder

masm\\ml.exe /c /coff /Fo intermediate\\%targ%.obj /I irvine /W3 asm\\%targ%.asm

:: create the .exe file in exe folder

masm\\link.exe /OUT:exe\\%targ%.exe /NOLOGO /LIBPATH:irvine user32.lib irvine32.lib kernel32.lib user32.lib /SUBSYSTEM:CONSOLE /MACHINE:X86 intermediate\\%targ%.obj

:: run the .exe file

exe\\%targ%.exe
@echo on