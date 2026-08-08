extends RefCounted
class_name WeaponRenderer

var _frame_index: int = 0
var _frame_timer: float = 0.0
var _is_firing: bool = false
var _fire_frame_held: int = 0
var _bob_offset: float = 0.0
var _bob_phase: float = 0.0

func start_fire_animation() -> void:
	_is_firing = true
	_frame_index = 1
	_frame_timer = 0.0
	_fire_frame_held = 0

func update(delta: float, is_moving: bool) -> void:
	if is_moving:
		_bob_phase += delta * 8.0
		_bob_offset = sin(_bob_phase) * 2.0
	else:
		_bob_offset = lerp(_bob_offset, 0.0, delta * 8.0)

	if _is_firing:
		_frame_timer += delta
		if _frame_timer > 0.08:
			_frame_timer = 0.0
			_frame_index += 1
			_fire_frame_held += 1
			if _fire_frame_held >= 3:
				_is_firing = false
				_frame_index = 0
				_fire_frame_held = 0

func render(screen: Image) -> void:
	var weapon: int = Globals.player_weapon
	var frames: Array = Globals.weapon_sprites
	var frames_per_weapon: int = 5
	var frame_offset: int = weapon * frames_per_weapon

	if frames.is_empty():
		return
	if frame_offset + _frame_index >= frames.size():
		return

	var src_img: Image = frames[frame_offset + _frame_index]
	if src_img == null:
		return

	var w: int = src_img.get_width()
	var h: int = src_img.get_height()
	if w <= 0 or h <= 0:
		return

	var scale: float = 2.2
	var dw: int = int(float(w) * scale)
	var dh: int = int(float(h) * scale)
	if dw < 1 or dh < 1:
		return

	var dx: int = (Globals.SCREEN_WIDTH - dw) / 2
	var dy: int = 159 - dh + int(_bob_offset)

	var y_start: int = maxi(0, dy)
	var y_end: int = mini(159, dy + dh)
	for y: int in range(y_start, y_end):
		var src_y: int = int(float(y - dy) / float(dh) * float(h))
		if src_y < 0 or src_y >= h:
			continue
		for x: int in range(dw):
			var sx: int = dx + x
			if sx < 0 or sx >= Globals.SCREEN_WIDTH:
				continue
			var src_x: int = int(float(x) / float(dw) * float(w))
			if src_x < 0 or src_x >= w:
				continue
			var pixel: Color = src_img.get_pixel(src_x, src_y)
			if pixel.a > 0.01:
				screen.set_pixel(sx, y, pixel)