
# x86-masm-dev-environment

This repository provides an x86 masm assembly development environment for MASM with the [Irvine libraries](http://asmirvine.com/gettingStartedVS2017/index.htm). 

The purpose is to quickly prototype single-file assembly projects without having to manage Visual Studio solutions and with all the plugins of your favorite IDE.

## Copying MASM over

You must copy the MASM assembler into the masm folder to use this environment. I do not believe I can distribute the masm assembler as per the terms of the [microsoft visual studio community 2019 licensing agreement](https://visualstudio.microsoft.com/license-terms/mlt031819/)

If you install Visual Studio Community 2019, (and probably all other versions) you will have MASM (MSVC).

It is located at:

`C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Tools\MSVC\14.29.30133\bin\Hostx86\x86`

Copy all the contents of that folder to `./masm` to access the assembler.


## How to use

Put an assembly file in the "asm" folder, making sure it has the *.asm extension.

Run `assemble.bat` from the command line and pass it a parameter; your *.asm filename, without the extension.

Example command line:

`assemble myassemblyTest1`

The batch command will find `myassemblyTest1.asm` in the `./asm` folder.

It will create `myassemblyTest1.o` in the `intermediate` folder. 

It will create `myassemblyTest1.exe` in the `./exe` folder, which will be linked to the Irvine libraries.

The executable will be run.


## How I use it

I use this with Visual Studio Code and the [x86_64-assembly-vscode](https://github.com/13xforever/x86_64-assembly-vscode) extension.

I use it primarily for testing small stuff, but I have also written larger files this way. Included is an example project I wrote earlier this semester with my groupmate. 

## Resources

Here is a [list of the procedures Irvine provides](https://csc.csudh.edu/mmccullough/asm/help/). 

Here is [felix cloutiers instruction reference](https://www.felixcloutier.com/x86/)

I personally found Kip Irivne's book, *Assembly Language for x86 Processors* (ISBN: 978-0135381656), to be very informative. You can find info about it [here](http://asmirvine.com/).


Happy assembling!