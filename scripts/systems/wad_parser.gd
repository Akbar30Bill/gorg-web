extends RefCounted
class_name WADParser

class VSwapFile:
	var num_chunks: int = 0
	var sprite_start: int = 0
	var sound_start: int = 0
	var offsets: Array[int] = []
	var data: PackedByteArray

	func load_wall_texture(index: int) -> Image:
		if index < 0 or index >= sprite_start:
			return _placeholder_wall()
		var offset := offsets[index]
		var size := offsets[index + 1] - offset if index + 1 < offsets.size() else data.size() - offset
		if size < 4096:
			return _placeholder_wall()
		var pixel_data := data.slice(offset, offset + 4096)
		return Palette.indexed_to_rgba32(pixel_data, 64, 64)

	func load_sprite(index: int) -> Image:
		var real_index := sprite_start + index
		if real_index < sprite_start or real_index >= offsets.size():
			return _placeholder_sprite()
		var offset := offsets[real_index]
		if offset >= data.size():
			return _placeholder_sprite()
		return _parse_sprite_pic(data, offset)

	func _parse_sprite_pic(raw: PackedByteArray, pic_offset: int) -> Image:
		if pic_offset + 4 > raw.size():
			return _placeholder_sprite()

		var leftpix := raw.decode_u16(pic_offset)
		var rightpix := raw.decode_u16(pic_offset + 2)
		var sprite_w := rightpix - leftpix + 1
		if sprite_w <= 0 or sprite_w > 128:
			return _placeholder_sprite()

		var max_rows := 128
		var sprite_h := max_rows
		var row_min := max_rows
		var row_max := 0

		var pixel_map := {}
		pixel_map[-1] = 255

		var col_ofs_base := pic_offset + 4
		var col_offsets: Array[int] = []
		for c in sprite_w:
			if col_ofs_base + c * 2 + 2 > raw.size():
				break
			col_offsets.append(raw.decode_u16(col_ofs_base + c * 2))

		for c in sprite_w:
			var col_ofs := pic_offset + col_offsets[c]
			if col_ofs < 0 or col_ofs + 4 > raw.size():
				continue

			while col_ofs + 4 <= raw.size():
				var top := raw.decode_u16(col_ofs)
				var bottom := raw.decode_u16(col_ofs + 2)
				if top == 0 and bottom == 0:
					break
				col_ofs += 4

				var col_data_end := col_ofs + (bottom - top + 1)
				if col_data_end > raw.size():
					break

				row_min = mini(row_min, top)
				row_max = maxi(row_max, bottom)

				for r in range(top, bottom + 1):
					var px := raw[col_ofs + (r - top)]
					pixel_map[c * max_rows + r] = px

				col_ofs = col_data_end
				if col_ofs % 2 != 0:
					col_ofs += 1

		if row_max < row_min:
			return _placeholder_sprite()

		var actual_h := row_max - row_min + 1
		var rgba := PackedByteArray()
		rgba.resize(sprite_w * actual_h * 4)
		var out_idx := 0

		for y in range(row_min, row_max + 1):
			for x in range(sprite_w):
				var px: int = pixel_map.get(x * max_rows + y, 255)
				if px == 255:
					rgba[out_idx] = 0
					rgba[out_idx + 1] = 0
					rgba[out_idx + 2] = 0
					rgba[out_idx + 3] = 0
				else:
					var ci := px * 3
					if ci + 2 < Palette.VGA_PALETTE.size():
						rgba[out_idx] = Palette.VGA_PALETTE[ci]
						rgba[out_idx + 1] = Palette.VGA_PALETTE[ci + 1]
						rgba[out_idx + 2] = Palette.VGA_PALETTE[ci + 2]
						rgba[out_idx + 3] = 255
					else:
						rgba[out_idx] = 0
						rgba[out_idx + 1] = 0
						rgba[out_idx + 2] = 0
						rgba[out_idx + 3] = 0
				out_idx += 4

		return Image.create_from_data(sprite_w, actual_h, false, Image.FORMAT_RGBA8, rgba)

	func _placeholder_wall() -> Image:
		var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.5, 0.5, 0.5, 1.0))
		for x in 64:
			for y in 64:
				var c := Color(float((x ^ y) & 0x3F) / 64.0, float((x + y) & 0x3F) / 128.0, float(y & 0x3F) / 64.0)
				img.set_pixel(x, y, c)
		return img

	func _placeholder_sprite() -> Image:
		var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
		img.fill(Color(1.0, 0.0, 1.0, 0.5))
		return img


class VgaGraphFile:
	var offsets: Array[int] = []
	var data: PackedByteArray

	func load_lump(index: int) -> Image:
		if index < 0 or index >= offsets.size():
			return _placeholder()
		var offset := offsets[index]
		var next_offset := offsets[index + 1] if index + 1 < offsets.size() else data.size()
		var lump_data := data.slice(offset, next_offset)
		return _decompress_pic(lump_data)

	func _decompress_pic(lump: PackedByteArray) -> Image:
		if lump.size() < 4:
			return _placeholder()
		var width := lump.decode_u16(0)
		var height := lump.decode_u16(2)
		if width <= 0 or height <= 0 or width > 320 or height > 200:
			return _placeholder()

		var data_ofs := 4
		var rgba := PackedByteArray()
		rgba.resize(width * height * 4)
		rgba.fill(0)

		for x in width:
			if data_ofs + 2 > lump.size():
				break
			var col_ofs := lump.decode_u16(4 + x * 2)
			if col_ofs == 0:
				continue
			var pos := col_ofs
			while pos + 2 <= lump.size():
				var y_start := lump.decode_u16(pos)
				if y_start == 0:
					break
				var y_end := lump.decode_u16(pos + 2)
				pos += 4
				for y in range(y_start, y_end + 1):
					if pos >= lump.size():
						break
					var ci := lump[pos] * 3
					pos += 1
					var out_idx := (y * width + x) * 4
					if ci + 2 < Palette.VGA_PALETTE.size():
						rgba[out_idx] = Palette.VGA_PALETTE[ci]
						rgba[out_idx + 1] = Palette.VGA_PALETTE[ci + 1]
						rgba[out_idx + 2] = Palette.VGA_PALETTE[ci + 2]
						rgba[out_idx + 3] = 255
				if pos % 2 != 0:
					pos += 1

		return Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, rgba)

	func _placeholder() -> Image:
		return Image.create(64, 64, false, Image.FORMAT_RGBA8)


class GameMapsFile:
	var map_offsets: Array[int] = []
	var data: PackedByteArray

	func load_map(index: int) -> Array:
		if index < 0 or index >= map_offsets.size():
			return _build_default_map()
		var offset := map_offsets[index]
		var compressed := data.slice(offset)
		var decompressed := Carmack.decompress(compressed)
		return _rlew_expand(decompressed)

	func _rlew_expand(data: PackedByteArray) -> Array:
		const RLEW_TAG: int = 0xABCD
		if data.size() < 2:
			return _build_default_map()
		var rlew_tag := data.decode_u16(0)
		if rlew_tag != RLEW_TAG:
			return _simple_read_map(data)

		var map: Array = []
		map.resize(Globals.MAP_WIDTH * Globals.MAP_HEIGHT)
		map.fill(0)

		var pos := 2
		var out_pos := 0
		while pos + 1 < data.size():
			var val: int = data.decode_u16(pos)
			pos += 2
			if val == RLEW_TAG:
				if pos + 2 > data.size():
					break
				var count: int = data.decode_u16(pos)
				pos += 2
				var tile: int = data.decode_u16(pos)
				pos += 2
				for _c in count:
					if out_pos < map.size():
						map[out_pos] = tile
						out_pos += 1
			else:
				if out_pos < map.size():
					map[out_pos] = val
					out_pos += 1

		return map

	func _simple_read_map(data: PackedByteArray) -> Array:
		var map: Array = []
		var total := Globals.MAP_WIDTH * Globals.MAP_HEIGHT
		map.resize(total)
		for i in range(0, mini(data.size() / 2 * 2, total * 2), 2):
			map[i / 2] = data.decode_u16(i)
		return map

	func _build_default_map() -> Array:
		var m: Array = []
		var total := Globals.MAP_WIDTH * Globals.MAP_HEIGHT
		m.resize(total)
		m.fill(0)

		var layout := [
			[1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],
			[1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1],
			[1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1],
			[1,0,0,1,1,1,0,0,0,0,1,1,1,0,0,1],
			[1,0,0,1,0,0,0,0,0,0,0,0,1,0,0,1],
			[1,0,0,1,0,0,0,0,0,0,0,0,1,0,0,1],
			[1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1],
			[1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1],
			[1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1],
			[1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1],
			[1,0,0,1,0,0,0,0,0,0,0,0,1,0,0,1],
			[1,0,0,1,0,0,0,0,0,0,0,0,1,0,0,1],
			[1,0,0,1,1,1,0,0,0,0,1,1,1,0,0,1],
			[1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1],
			[1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1],
			[1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],
		]

		for y in 16:
			for x in 16:
				if x < layout[y].size():
					m[y * Globals.MAP_WIDTH + x] = layout[y][x]

		return m


static func load_vswap(path: String) -> VSwapFile:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("Could not open VSWAP: " + path)
		return null

	var vswap := VSwapFile.new()
	vswap.data = file.get_buffer(file.get_length())

	if vswap.data.size() < 6:
		file.close()
		return null

	vswap.num_chunks = vswap.data.decode_u16(0)
	vswap.sprite_start = vswap.data.decode_u16(2)
	vswap.sound_start = vswap.data.decode_u16(4)

	vswap.offsets.resize(vswap.num_chunks)
	for i in vswap.num_chunks:
		var ofs_start := 6 + i * 4
		if ofs_start + 4 <= vswap.data.size():
			vswap.offsets[i] = vswap.data.decode_u32(ofs_start)

	file.close()
	return vswap


static func load_vgagraph(path: String) -> VgaGraphFile:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null

	var vga := VgaGraphFile.new()
	vga.data = file.get_buffer(file.get_length())
	file.close()

	if vga.data.size() < 8:
		return null

	var pos := 0
	while pos + 4 <= vga.data.size():
		var offset := vga.data.decode_u32(pos)
		if offset == 0 or offset >= vga.data.size():
			break
		vga.offsets.append(offset)
		pos += 4

	return vga


static func load_gamemaps(maphead_path: String, gamemaps_path: String) -> GameMapsFile:
	var header_file := FileAccess.open(maphead_path, FileAccess.READ)
	if header_file == null:
		return null

	var maps := GameMapsFile.new()

	if header_file.get_length() >= 4:
		var rlew_tag := header_file.get_buffer(2)

	while header_file.get_position() + 4 <= header_file.get_length():
		var offset := header_file.get_32()
		if offset >= 0:
			maps.map_offsets.append(offset)

	header_file.close()

	var map_file := FileAccess.open(gamemaps_path, FileAccess.READ)
	if map_file != null:
		maps.data = map_file.get_buffer(map_file.get_length())
		map_file.close()

	return maps