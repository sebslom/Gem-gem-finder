class_name GemChunk
extends RefCounted

const SIZE = 32
const STRIDE = 8
const BYTE_COUNT = SIZE * SIZE * STRIDE
var data := PackedByteArray()
var dirty := true

func _init() -> void:
	data.resize(BYTE_COUNT)

func encode() -> PackedByteArray:
	# RLE compares all eight bytes, including walls, fluids and explored flags.
	var output := PackedByteArray()
	var cell := 0
	while cell < 1024:
		var run := 1
		while cell + run < 1024 and run < 65535:
			var equal := true
			for field in STRIDE:
				if data[cell * STRIDE + field] != data[(cell + run) * STRIDE + field]:
					equal = false
					break
			if not equal:
				break
			run += 1
		output.append(run & 255)
		output.append(run >> 8)
		output.append_array(data.slice(cell * STRIDE, cell * STRIDE + STRIDE))
		cell += run
	return output

func decode(encoded: PackedByteArray) -> bool:
	if encoded.size() % 10 != 0 or encoded.size() > 10240:
		return false
	var restored := PackedByteArray()
	restored.resize(BYTE_COUNT)
	var cell := 0
	for offset in range(0, encoded.size(), 10):
		var run := int(encoded[offset]) | (int(encoded[offset + 1]) << 8)
		if run == 0 or cell + run > 1024:
			return false
		for i in run:
			for field in STRIDE:
				restored[(cell + i) * STRIDE + field] = encoded[offset + 2 + field]
		cell += run
	if cell != 1024:
		return false
	data = restored
	dirty = true
	return true
