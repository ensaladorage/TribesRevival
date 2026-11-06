extends RefCounted
## Counts use integer text, including JSON-decoded floats. Effects may be fractional.

static func integer(value: float) -> String:
	return str(roundi(value)) if is_finite(value) else "0"

static func bonus(value: float, unit: String) -> String:
	if not is_finite(value):
		value = 0.0
	var text := integer(value) if is_equal_approx(value, roundf(value)) else String.num(value, 2).replace(".", ",")
	return "%s%s %s" % ["+" if value >= 0.0 else "", text, unit]
