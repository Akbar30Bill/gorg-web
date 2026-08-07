extends RefCounted
class_name Carmack

const NEARTAG := 0xA7
const FARTAG := 0xA8

static func decompress(source: PackedByteArray) -> PackedByteArray:
	if source.size() < 2:
		return PackedByteArray()

	var src_words: Array[int] = []
	for i in range(0, source.size() - 1, 2):
		src_words.append(source.decode_u16(i))

	var length := src_words.size()
	var src_pos := 0
	var dest: Array[int] = []
	var max_output := 65536

	while src_pos < length and dest.size() < max_output:
		var ch := src_words[src_pos]
		src_pos += 1
		var chhigh := ch >> 8
		var count := ch & 0xFF

		if chhigh == NEARTAG:
			if count == 0:
				if src_pos >= length:
					break
				dest.append(src_words[src_pos])
				src_pos += 1
			else:
				if src_pos >= length:
					break
				var offset := src_words[src_pos]
				src_pos += 1
				for _c in count:
					if dest.size() >= max_output:
						break
					if offset > dest.size():
						break
					dest.append(dest[dest.size() - offset])

		elif chhigh == FARTAG:
			if count == 0:
				if src_pos >= length:
					break
				dest.append(src_words[src_pos])
				src_pos += 1
			else:
				if src_pos >= length:
					break
				var offset := src_words[src_pos]
				src_pos += 1
				for _c in count:
					if dest.size() >= max_output:
						break
					if offset >= dest.size():
						dest.append(0)
					else:
						dest.append(dest[offset])
						offset += 1

		else:
			dest.append(ch)

	var out := PackedByteArray()
	out.resize(dest.size() * 2)
	for i in dest.size():
		var w := dest[i] & 0xFFFF
		out.encode_u16(i * 2, w)
	return out