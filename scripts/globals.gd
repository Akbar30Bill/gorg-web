extends Node

const SCREEN_WIDTH := 320
const SCREEN_HEIGHT := 200
const TILE_SIZE := 64
const MAP_WIDTH := 64
const MAP_HEIGHT := 64
const NUM_WALL_TEXTURES := 64
const FOV := 60.0
const HALF_FOV := FOV * 0.5
const PLAYER_SPEED := 180.0
const ROTATION_SPEED := 120.0
const MOUSE_SENSITIVITY := 0.2

enum GameState { TITLE, PLAYING, DEAD, INTERMISSION, VICTORY }
enum WeaponType { KNIFE, PISTOL, MACHINE_GUN, CHAIN_GUN }

var game_state: GameState = GameState.TITLE
var player_pos: Vector2 = Vector2.ZERO
var player_angle: float = 0.0
var player_health: int = 100
var player_ammo: int = 8
var player_lives: int = 3
var player_score: int = 0
var player_keys: int = 0
var player_weapon: int = 2
var current_level: int = 0
var current_episode: int = 1

var wall_textures: Array[Image] = []
var sprite_images: Array[Image] = []
var face_sprites: Array[Image] = []
var vgagraph: RefCounted = null
var map_data: Array = []
var door_map: Array = []
var actor_map: Array = []

var face_state: int = 0
var face_frame: int = 0
var face_timer: float = 0.0
var face_hurt_timer: float = 0.0
var face_happy_timer: float = 0.0

enum FaceState { NEUTRAL = 0, HAPPY = 1, HURT = 2, LOW = 3, GOD = 4 }
const FACE_ANIM_SPEED := 0.15
const FACE_HURT_DURATION := 2.0
const FACE_HAPPY_DURATION := 1.5

var screen_image: Image
var screen_texture: ImageTexture
var z_buffer: Array = []
var texture_rect: TextureRect

var wad_loaded: bool = false