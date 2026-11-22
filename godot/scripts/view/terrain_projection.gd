extends RefCounted
const T = preload("res://scripts/simulation/island_terrain.gd")
const PITCH := PI / 3.0
const DEPTH_SCALE := 1.0 / sin(PITCH)
const RISE := T.TILE / cos(PITCH)

static func world(p: Dictionary, rows: Array) -> Vector3:
	return Vector3(p.x, RISE * T.fraction(rows,p), float(p.y) * DEPTH_SCALE)

static func logical(p: Vector3) -> Dictionary:
	return {"x":p.x, "y":p.z / DEPTH_SCALE}
