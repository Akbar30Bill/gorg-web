# Gorg-Web

**Wolfenstein 3D engine clone** built with **Godot 4**, deployable to **Netlify** as a web game.

> A faithful reimplementation of the id Software Wolfenstein 3D raycasting engine in GDScript, running in the browser.

## Status

- [x] Project scaffold + WAD parser + palette
- [x] DDA raycasting engine
- [x] Wall texture rendering (floor/ceiling colors)
- [x] Player movement + collision detection
- [ ] Sprite rendering (enemies, objects)
- [ ] Doors and pushwalls
- [ ] Weapons + combat
- [ ] Enemy AI + pathfinding
- [ ] HUD, menus, sound
- [ ] Web export + Netlify deploy

## Setup

1. Install [Godot 4.5+](https://godotengine.org/)
2. Clone this repo
3. Obtain the Wolfenstein 3D shareware data files (`.WL6`) and place them in `assets/wolf3d/`:
   - `VSWAP.WL6`, `GAMEMAPS.WL6`, `MAPHEAD.WL6`, `VGAGRAPH.WL6`, `VGAHEAD.WL6`, `VGADICT.WL6`, `AUDIOHED.WL6`, `AUDIOT.WL6`
4. Run `python tools/download_assets.py` for instructions on obtaining files
5. Open the project in Godot and press F5

If no WAD files are present, the engine renders with procedurally generated placeholder textures.

## Controls

| Key | Action |
|-----|--------|
| W / Up | Move forward |
| S / Down | Move backward |
| A | Strafe left |
| D | Strafe right |
| Left/Right | Rotate |
| Mouse (click to capture) | Look around |
| Escape | Release mouse |

## Architecture

```
gorg-web/
├── project.godot              # Godot project config
├── netlify.toml               # Netlify COOP/COEP headers
├── scripts/
│   ├── main.gd                # Entry point, game loop
│   ├── globals.gd             # Constants, shared state (autoload)
│   ├── raycaster/
│   │   ├── raycast_engine.gd  # DDA wall detection
│   │   ├── wall_renderer.gd   # Textured wall columns
│   │   └── floor_ceiling.gd   # Floor/ceiling color fill
│   ├── systems/
│   │   ├── palette.gd         # VGA 256-color palette → RGBA
│   │   ├── wad_parser.gd      # VSWAP/VGAGRAPH/GAMEMAPS binary parser
│   │   └── carmack.gd         # Carmack RLE decompressor
│   └── game/                  # (coming in Phase 2-3)
├── assets/wolf3d/             # Place .WL6 files here
└── scenes/main.tscn           # Main scene
```

## Deploying to Netlify

1. Export from Godot: **Project → Export → HTML5**
2. Deploy the `export/html5/` directory to Netlify
3. The `netlify.toml` in this repo sets the required COOP/COEP headers for SharedArrayBuffer

## License

This project is an original reimplementation inspired by the Wolfenstein 3D source code (originally released by id Software under a Limited Use Software License Agreement for educational purposes). No original id Software code is used. Game data files are not included — users must provide their own legally obtained copies.