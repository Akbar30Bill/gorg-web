# Gorg-Web

**Wolfenstein 3D engine clone** built with **Godot 4**, deployable to **Netlify** as a web game.

> A faithful reimplementation of the id Software Wolfenstein 3D raycasting engine in GDScript, running in the browser at 60fps.

## Status

- [x] Project scaffold + WAD parser + VGA palette
- [x] DDA raycasting engine (320 rays/frame)
- [x] Textured wall columns + floor/ceiling
- [x] Player movement + collision + mouse look
- [x] Billboard sprite rendering with z-buffer
- [x] Door system (open/close/locked/gold/silver keys)
- [x] Pushwalls and secret detection
- [x] 4 weapons: knife, pistol, machine gun, chaingun
- [x] 6 enemy types with state machines, chase, attack AI
- [x] Pickups: health, ammo, keys, treasures, weapons
- [x] HUD with health bar, ammo, score, keys, face
- [x] Main menu, controls screen, load game
- [x] PC Speaker sound emulation (procedural audio)
- [x] Save/Load (6 slots)
- [x] Intermission screen, death screen, level progression
- [x] Web export config + Netlify deployment

## Setup

1. Install [Godot 4.5+](https://godotengine.org/)
2. Clone this repo: `git clone https://github.com/Akbar30Bill/gorg-web.git`
3. Obtain Wolfenstein 3D shareware data files (`.WL6`) and place them in `assets/wolf3d/`:
   - `VSWAP.WL6`, `GAMEMAPS.WL6`, `MAPHEAD.WL6`, `VGAGRAPH.WL6`, `VGAHEAD.WL6`, `VGADICT.WL6`, `AUDIOHED.WL6`, `AUDIOT.WL6`
4. Run `python tools/download_assets.py` for help obtaining the files
5. Open the project in Godot and press **F5** to run

> Without WAD files, the engine renders with procedurally generated placeholder textures and a default test level.

## Controls

| Key | Action |
|-----|--------|
| W / Up | Move forward |
| S / Down | Move backward |
| A | Strafe left |
| D | Strafe right |
| Left / Right | Rotate view |
| Mouse (click to capture) | Look around |
| Ctrl / Left Click | Fire weapon |
| 1-4 | Switch weapon |
| E / Space | Open door |
| Escape | Release mouse |

## Deploying to Netlify

### 1. Export from Godot

- **Project → Export → HTML5**
- Output: `export/html5/index.html`

### 2. Deploy to Netlify

**Option A: Drag & drop**
- Go to [app.netlify.com](https://app.netlify.com)
- Drag the `export/html5/` folder onto the drop zone

**Option B: Netlify CLI**
```bash
netlify deploy --prod --dir=export/html5
```

**Option C: Git-based CI**
- Connect your GitHub repo to Netlify
- Set build command: `mkdir -p dist && cp -r export/html5/* dist/`
- Set publish directory: `dist`
- Netlify reads `netlify.toml` for the required COOP/COEP headers

### Why COOP/COEP headers?

Godot 4 web exports use `SharedArrayBuffer` for threading, which requires:
- `Cross-Origin-Opener-Policy: same-origin`
- `Cross-Origin-Embedder-Policy: require-corp`

These are configured in `netlify.toml` and are automatically applied by Netlify.

## Architecture

```
gorg-web/
├── project.godot              # Godot project config (autoloads, display, rendering)
├── netlify.toml               # Netlify COOP/COEP headers for SharedArrayBuffer
├── export_presets.cfg         # HTML5 export configuration
├── scripts/
│   ├── main.gd                # Bootstrap, game loop, state machine
│   ├── globals.gd             # Constants, enums, shared state (autoload)
│   ├── raycaster/
│   │   ├── raycast_engine.gd  # DDA wall detection (320 rays/frame)
│   │   ├── wall_renderer.gd   # Textured wall column scaling
│   │   ├── sprite_renderer.gd # Billboard sprites with z-buffer sorting
│   │   └── floor_ceiling.gd   # Floor/ceiling color fill
│   ├── game/
│   │   ├── level.gd           # Map loader, door state machine, pushwalls
│   │   ├── enemies.gd         # 6 enemy types, state machines, chase AI
│   │   ├── weapons.gd         # 4 weapon definitions, fire rate, ammo
│   │   ├── projectiles.gd     # Hitscan bullets, melee detection
│   │   ├── pickups.gd         # 12 pickup types (health, ammo, keys, treasures)
│   │   └── hud.gd             # Status bar, health bar, ammo, score, bitmap font
│   ├── systems/
│   │   ├── palette.gd         # VGA 256-color palette → RGBA32 converter
│   │   ├── wad_parser.gd      # VSWAP/VGAGRAPH/GAMEMAPS binary file parser
│   │   ├── carmack.gd         # Carmack RLE compression decompressor
│   │   ├── sound_manager.gd   # Procedural PC Speaker audio (square/triangle/sine)
│   │   └── save_manager.gd    # JSON save/load with 6 slots
│   └── ui/
│       ├── main_menu.gd       # Title screen, navigation, load game, controls
│       └── intermission.gd    # Level complete stats screen
├── scenes/main.tscn           # Main scene (Control + TextureRect)
├── assets/wolf3d/             # Place .WL6 files here
└── tools/
    └── download_assets.py     # Asset acquisition helper script
```

## Technical Details

### Raycasting
- DDA (Digital Differential Analyzer) algorithm
- 320 rays per frame (one per screen column)
- Perpendicular distance calculation to eliminate fisheye
- Texture-mapped walls with column-based scaling
- Z-buffer maintained for sprite occlusion

### WAD File Format
- **VSWAP**: Wall textures (64×64 raw indexed) + sprites (pic format with column offsets)
- **VGAGRAPH**: Compressed graphics lumps (title screens, UI elements)
- **GAMEMAPS + MAPHEAD**: Carmack-compressed + RLEW-encoded 64×64 tile maps

### Sound
Procedurally generated PC Speaker-style audio using Godot's `AudioStreamGenerator`:
- Square, triangle, and sine wave generators
- ADSR-style envelope for attack/sustain/decay
- Sound effects: door, pistol, enemy hit/death, pickup, secret

### Performance
- Target: 60fps at 320×200
- Rendered to `Image` buffer, displayed via `ImageTexture` on `TextureRect`
- Upscaled with nearest-neighbor filtering for genuine pixel art look

## License

This project is an original reimplementation inspired by Wolfenstein 3D. No original id Software code is included. Game data files are not distributed — users must provide their own legally obtained copies.