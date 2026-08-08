extends RefCounted
class_name WADParser

class VSwapFile:
	var num_chunks: int = 0
	var sprite_start: int = 0
	var sound_start: int = 0
	var offsets: Array[int] = []
	var lengths: Array[int] = []
	var data: PackedByteArray

	func load_wall_texture(index: int) -> Image:
		if index < 0 or index >= sprite_start:
			return _placeholder_wall()
		var offset: int = offsets[index]
		if index < lengths.size() and lengths[index] >= 4096:
			var pixel_data: PackedByteArray = data.slice(offset, offset + 4096)
			return Palette.indexed_to_rgba32(pixel_data, 64, 64)
		return _placeholder_wall()

	func load_sprite(index: int) -> Image:
		var real_index: int = sprite_start + index
		if real_index < sprite_start or real_index >= offsets.size():
			return _placeholder_sprite()
		var offset: int = offsets[real_index]
		if offset <= 0 or offset >= data.size():
			return _placeholder_sprite()
		var chunk_len: int = 0
		if real_index < lengths.size():
			chunk_len = lengths[real_index]
		return _parse_sprite_pic(data, offset, chunk_len)

	func _parse_sprite_pic(raw: PackedByteArray, pic_offset: int, chunk_len: int) -> Image:
		if pic_offset + 4 > raw.size():
			return _placeholder_sprite()

		var chunk_end: int = pic_offset + chunk_len if chunk_len > 0 else raw.size()
		if chunk_end > raw.size():
			chunk_end = raw.size()

		var leftpix: int = raw.decode_u16(pic_offset)
		var rightpix: int = raw.decode_u16(pic_offset + 2)
		var sprite_w: int = rightpix - leftpix + 1
		if sprite_w <= 0 or sprite_w > 256:
			return _placeholder_sprite()

		var col_data_start: int = pic_offset + 4 + sprite_w * 2
		var col_offsets: Array[int] = []
		for c: int in range(sprite_w):
			col_offsets.append(raw.decode_u16(pic_offset + 4 + c * 2))

		const SOURCE_ROWS := 64
		var indexed: PackedByteArray = PackedByteArray()
		indexed.resize(sprite_w * SOURCE_ROWS)
		indexed.fill(255)

		for c: int in range(col_offsets.size()):
			var pos: int = pic_offset + col_offsets[c]
			if pos < pic_offset or pos > chunk_end:
				continue

			while pos + 6 <= chunk_end:
				var endpix2: int = raw.decode_u16(pos)
				if endpix2 == 0:
					break
				var top: int = raw.decode_u16(pos + 2)
				var startpix2: int = raw.decode_u16(pos + 4)
				pos += 6

				var start_row: int = startpix2 / 2
				var end_row: int = endpix2 / 2
				if start_row >= end_row or start_row >= SOURCE_ROWS or end_row > SOURCE_ROWS:
					continue

				var run_len: int = end_row - start_row
				var src_ofs: int = col_data_start + top + start_row
				if src_ofs < 0 or src_ofs + run_len > raw.size() or src_ofs + run_len > chunk_end:
					continue

				for r: int in range(start_row, end_row):
					indexed[c * SOURCE_ROWS + r] = raw[src_ofs + (r - start_row)]

		return Palette.indexed_to_rgba32_transparent(indexed, sprite_w, SOURCE_ROWS, 255)

	func _placeholder_wall() -> Image:
		var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.5, 0.5, 0.5, 1.0))
		for x: int in range(64):
			for y: int in range(64):
				var c: Color = Color(float((x ^ y) & 0x3F) / 64.0, float((x + y) & 0x3F) / 128.0, float(y & 0x3F) / 64.0)
				img.set_pixel(x, y, c)
		return img

	func _placeholder_sprite() -> Image:
		var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
		img.fill(Color(1.0, 0.0, 1.0, 0.5))
		return img


class VgaGraphFile:
	var data: PackedByteArray
	var chunks: Array = []
	var chunk_count: int = 0

	func _huff_decompress(data: PackedByteArray, src_ofs: int) -> PackedByteArray:
		if src_ofs + 16 > data.size():
			return PackedByteArray()

		var nodes: Array = []
		nodes.resize(256)
		for i: int in range(256):
			nodes[i] = 0

		var src_pos: int = src_ofs
		for i: int in range(254):
			if src_pos + 4 > data.size():
				return PackedByteArray()
			var val0: int = data.decode_u16(src_pos)
			var val1: int = data.decode_u16(src_pos + 2)
			src_pos += 4
			if val0 < 256:
				nodes[i] = nodes[i] & 0xFFFF0000 | val0
			else:
				nodes[i] = nodes[i] & 0xFFFF0000 | ((val0 - 256) | 0x100)
			if val1 < 256:
				nodes[i] = nodes[i] & 0x0000FFFF | (val1 << 16)
			else:
				nodes[i] = nodes[i] & 0x0000FFFF | (((val1 - 256) | 0x100) << 16)

		var length: int = data.decode_u32(src_pos)
		src_pos += 4
		if length <= 0 or length > 262144:
			length = 65536

		var result: PackedByteArray = PackedByteArray()
		result.resize(length)
		var res_pos: int = 0
		var node_val: int = nodes[254]
		var node_idx: int = 254
		var src_byte: int = 0
		var bit_mask: int = 1
		var bit_source: int = 0

		while src_pos < data.size() and res_pos < length:
			if bit_source == 0:
				if src_pos >= data.size():
					break
				src_byte = data[src_pos]
				src_pos += 1
				bit_source = 8

			var bit: int = src_byte & bit_mask
			bit_mask <<= 1
			bit_source -= 1
			if bit_source == 0:
				bit_mask = 1

			if bit != 0:
				var val: int = (nodes[node_idx] >> 16) & 0xFFFF
				if val < 256:
					if res_pos < length:
						result[res_pos] = val
					res_pos += 1
					node_idx = 254
				else:
					node_idx = val & 0xFF
			else:
				var val: int = nodes[node_idx] & 0xFFFF
				if val < 256:
					if res_pos < length:
						result[res_pos] = val
					res_pos += 1
					node_idx = 254
				else:
					node_idx = val & 0xFF

		return result.slice(0, res_pos)

	func load_lump(index: int) -> Image:
		if index < 0 or index >= chunks.size():
			return _placeholder()
		return _decompress_pic(chunks[index])

	func load_all() -> void:
		chunks.clear()
		if data.size() < 8:
			return
		var pos: int = 0
		while pos + 4 <= data.size():
			var offset: int = data.decode_u32(pos)
			if offset == 0 or offset >= data.size():
				break
			pos += 4
		chunk_count = pos / 4

		for i: int in range(chunk_count):
			var chunk_start: int = data.decode_u32(i * 4)
			var chunk_end: int
			if i + 1 < chunk_count:
				chunk_end = data.decode_u32((i + 1) * 4)
			else:
				chunk_end = data.size()

			if chunk_end > chunk_start and chunk_end <= data.size():
				var lump: PackedByteArray = data.slice(chunk_start, chunk_end)
				chunks.append(lump)

	func _decompress_pic(lump: PackedByteArray) -> Image:
		if lump.size() < 4:
			return _placeholder()
		var width: int = lump.decode_u16(0)
		var height: int = lump.decode_u16(2)
		if width == 0 or height == 0 or width > 320 or height > 200:
			if lump.size() > 1024:
				var decomp: PackedByteArray = _huff_decompress(lump, 0)
				if decomp.size() >= 4 and decomp.size() < 128000:
					var w: int = decomp.decode_u16(0)
					var h: int = decomp.decode_u16(2)
					if w > 0 and h > 0 and w <= 320 and h <= 200:
						return _build_pic_image(decomp, w, h)
			return _placeholder()

		return _build_pic_image(lump, width, height)

	func _build_pic_image(raw: PackedByteArray, width: int, height: int) -> Image:
		var rgba: PackedByteArray = PackedByteArray()
		rgba.resize(width * height * 4)
		rgba.fill(0)

		for x: int in range(width):
			if 4 + x * 2 + 2 > raw.size():
				break
			var col_ofs: int = raw.decode_u16(4 + x * 2)
			if col_ofs == 0:
				continue
			var pos: int = col_ofs
			while pos + 4 <= raw.size():
				var y_start: int = raw.decode_u16(pos)
				if y_start == 0:
					pos += 4
					break
				var y_end: int = raw.decode_u16(pos + 2)
				if y_end < y_start or y_start > 255 or y_end > 255:
					break
				pos += 4
				for y: int in range(y_start, y_end + 1):
					if pos >= raw.size():
						break
					var ci: int = raw[pos] * 3
					pos += 1
					var out_idx: int = (y * width + x) * 4
					if ci + 2 < Palette.VGA_PALETTE.size() and out_idx + 3 < rgba.size():
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

	func load_map(index: int) -> Dictionary:
		if map_offsets.is_empty():
			return {"plane0": _build_default_map(), "plane1": _build_default_map(), "plane2": []}

		var total_planes: int = 3
		var plane_indices: Array[int] = []
		for p: int in range(total_planes):
			var pi: int = index * total_planes + p
			if pi < map_offsets.size() and map_offsets[pi] > 0:
				plane_indices.append(pi)

		if plane_indices.is_empty():
			return {"plane0": _build_default_map(), "plane1": _build_default_map(), "plane2": []}

		var planes: Array[Array] = [[], [], []]

		for pi_idx: int in range(plane_indices.size()):
			var pi: int = plane_indices[pi_idx]
			var start: int = map_offsets[pi]
			var end: int = data.size()

			var next_pi: int = pi + 1
			while next_pi < map_offsets.size():
				if map_offsets[next_pi] > 0:
					end = map_offsets[next_pi]
					break
				next_pi += 1

			if end <= start or start >= data.size():
				continue

			var compressed: PackedByteArray = data.slice(start, end)
			var decompressed: PackedByteArray = Carmack.decompress(compressed)
			var plane_index: int = pi % total_planes
			planes[plane_index] = _rlew_expand(decompressed)

		return {
			"plane0": planes[0] if not planes[0].is_empty() else _build_default_map(),
			"plane1": planes[1] if not planes[1].is_empty() else _build_default_map(),
			"plane2": planes[2],
		}

	func _rlew_expand(data: PackedByteArray) -> Array:
		const RLEW_TAG: int = 0xABCD
		if data.size() < 2:
			return _build_default_map()
		var rlew_tag: int = data.decode_u16(0)
		if rlew_tag != RLEW_TAG:
			return _simple_read_map(data)

		var map: Array = []
		map.resize(Globals.MAP_WIDTH * Globals.MAP_HEIGHT)
		map.fill(0)

		var pos: int = 2
		var out_pos: int = 0
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
				for _c: int in range(count):
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
		var total: int = Globals.MAP_WIDTH * Globals.MAP_HEIGHT
		map.resize(total)
		for i: int in range(0, mini(data.size() / 2 * 2, total * 2), 2):
			map[i / 2] = data.decode_u16(i)
		return map

	func _build_default_map() -> Array:
		var m: Array = []
		var total: int = Globals.MAP_WIDTH * Globals.MAP_HEIGHT
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

		for y: int in range(16):
			for x: int in range(16):
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
	for i: int in range(vswap.num_chunks):
		var ofs_start: int = 6 + i * 4
		if ofs_start + 4 <= vswap.data.size():
			vswap.offsets[i] = vswap.data.decode_u32(ofs_start)

	var lengths_base: int = 6 + vswap.num_chunks * 4
	vswap.lengths.resize(vswap.num_chunks)
	for i: int in range(vswap.num_chunks):
		var len_start: int = lengths_base + i * 2
		if len_start + 2 <= vswap.data.size():
			vswap.lengths[i] = vswap.data.decode_u16(len_start)

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

	vga.load_all()
	return vga


static func load_gamemaps(maphead_path: String, gamemaps_path: String) -> GameMapsFile:
	var header_file := FileAccess.open(maphead_path, FileAccess.READ)
	if header_file == null:
		return null

	var maps := GameMapsFile.new()

	if header_file.get_length() >= 4:
		var rlew_tag: PackedByteArray = header_file.get_buffer(2)

	while header_file.get_position() + 4 <= header_file.get_length():
		var offset: int = header_file.get_32()
		if offset >= 0:
			maps.map_offsets.append(offset)

	header_file.close()

	var map_file := FileAccess.open(gamemaps_path, FileAccess.READ)
	if map_file != null:
		maps.data = map_file.get_buffer(map_file.get_length())
		map_file.close()

	return maps