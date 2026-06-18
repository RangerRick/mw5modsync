Mechwarrior 5 Mod Sync
======================

Welcome!

If you are reading this, you are probably one of only a handful of people.

This script syncs a curated list of Mechwarrior 5 mods with the `mods` directory of an installed version of Mechwarrior 5.

Installation
------------

1. click `Code` on this GitHub page, and select `Download ZIP`
2. unpack the downloaded ZIP file (this tool will not work if you just run things inside the ZIP file)
3. that's it! (optional: see "Running" for custom mod folder paths)

Running
-------

Click on the `RUNME` script to run with the default mod folder (`C:\Program Files\Epic Games\MW5Mercs`).

To use a custom mod folder path, pass the `-MW5MercsFolder` parameter:

```powershell
.\mw5-sync.ps1 -MW5MercsFolder "D:\CustomPath\MW5Mercs"
```

The script automatically requests administrative privileges.
You do _not_ want to know how it asks for administrative privileges.
Seriously.
