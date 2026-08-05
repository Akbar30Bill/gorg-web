#!/usr/bin/env python3
"""
Download shareware Wolfenstein 3D data files.
These files are legally available from the Wolfenstein 3D shareware release.

The shareware installer (1wolf14.zip or similar) contains:
  - VSWAP.WL6    (wall textures + sprites)
  - GAMEMAPS.WL6 (level maps)
  - MAPHEAD.WL6  (map offsets)
  - VGAGRAPH.WL6 (title screens, menu graphics)
  - VGAHEAD.WL6  (graphics offsets)
  - VGADICT.WL6  (graphics dictionary)
  - AUDIOHED.WL6 (sound offsets)
  - AUDIOT.WL6   (sound data)

Place extracted files in: assets/wolf3d/
"""

import os
import sys
import shutil
import zipfile
import urllib.request
import tempfile

ASSETS_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "assets", "wolf3d")
EXPECTED_FILES = [
    "VSWAP.WL6", "GAMEMAPS.WL6", "MAPHEAD.WL6",
    "VGAGRAPH.WL6", "VGAHEAD.WL6", "VGADICT.WL6",
    "AUDIOHED.WL6", "AUDIOT.WL6",
]

def main():
    os.makedirs(ASSETS_DIR, exist_ok=True)

    existing = [f for f in EXPECTED_FILES if os.path.exists(os.path.join(ASSETS_DIR, f))]
    if len(existing) == len(EXPECTED_FILES):
        print("All WAD files already present in assets/wolf3d/")
        return

    print("Wolfenstein 3D data files are required to run the game.")
    print("")
    print("Option 1: Place the following files in assets/wolf3d/")
    for f in EXPECTED_FILES:
        print(f"  - {f}")
    print("")
    print("Option 2: Obtain the shareware version of Wolfenstein 3D from")
    print("  any of these sources:")
    print("  - https://archive.org/details/Wolfenstein3d")
    print("  - https://www.dosgamesarchive.com/download/wolfenstein-3d/")
    print("")
    print("Then copy the *.WL6 files to assets/wolf3d/")
    print("")
    print("Option 3: Use a dedicated tool like WOLF4SDL or ECWolf to extract")
    print("  data from a purchased copy of the game.")
    print("")
    print("Once files are placed, the game will load them automatically at runtime.")
    print("If no data files are found, the engine will use placeholder textures.")

if __name__ == "__main__":
    main()