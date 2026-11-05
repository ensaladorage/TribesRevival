class_name TribeRandom
extends RefCounted
## Bit-exact FNV-1a (UTF-16) + Mulberry32 port of seededRandom.ts.

const MASK := 0xffffffff
var _state: int

func _init(seed_text: String) -> void:
	_state = 2166136261
	for index in seed_text.length():
		var code := seed_text.unicode_at(index)
		if code > 0xffff:
			code -= 0x10000
			_hash_code(0xd800 + (code >> 10))
			_hash_code(0xdc00 + (code & 0x3ff))
		else:
			_hash_code(code)

func _hash_code(code: int) -> void:
	_state = ((_state ^ code) * 16777619) & MASK

func seed_hash() -> int:
	return _state

static func _imul(first: int, second: int) -> int:
	# Split into 16-bit limbs to avoid signed 64-bit overflow.
	var low := (first & 0xffff) * (second & 0xffff)
	var cross := ((first >> 16) * (second & 0xffff) + (first & 0xffff) * (second >> 16)) & 0xffff
	return (low + (cross << 16)) & MASK

func next_uint() -> int:
	_state = (_state + 0x6d2b79f5) & MASK
	var value := _imul(_state ^ (_state >> 15), 1 | _state)
	value = (value ^ ((value + _imul(value ^ (value >> 7), 61 | value)) & MASK)) & MASK
	return (value ^ (value >> 14)) & MASK

func next_float(minimum: float = 0.0, maximum: float = 1.0) -> float:
	return minimum + (float(next_uint()) / 4294967296.0) * (maximum - minimum)

func next_int(minimum: int, maximum: int) -> int:
	assert(maximum >= minimum, "next_int requires max >= min")
	return int(floor(next_float() * (maximum - minimum + 1))) + minimum
