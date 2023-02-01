Mechwarrior 5 Mod Sync
======================

Welcome!

If you are reading this, you are probably one of only a handful of people.

This script syncs a curated list of Mechwarrior 5 mods with the `mods` directory of an installed version of Mechwarrior 5.

Installation
------------

1. click `Code` on this GitHub page, and select `Download ZIP`
2. unpack the downloaded ZIP file (this tool will not work if you just run things inside the ZIP file)
3. install WSL (_you_ do not need to use WSL, but Docker does):
     1. right-click `install-wsl.bat`
     2. run it as `Administrator`
4. follow the instructions here to download and install Docker Desktop: https://docs.docker.com/desktop/install/windows-install/
5. if your MW5 is _not_ installed in `C:\Program Files\Epic Games\MW5Mercs`, edit the `do-sync.bat` file with Notepad and change the `SET MW5_PATH` line at the top

Running
-------

Once you have followed the installation steps above, all you should need to do is run the `do-sync` command.
The first run will probably be very slow, but subsequent runs will only download things that are new.
