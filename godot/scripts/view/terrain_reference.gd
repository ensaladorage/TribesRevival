extends Node3D
## F6 reference composition for projection, coast, stairs and cursor picking.
const View = preload("res://scripts/view/terrain_projection.gd")
const T = View.T
const MAP := [
	".........gggggggg.......",
	"...gggggggggggggggg.....",
	"..gggggggHHHHHHgggg.....",
	"..gggggggHHHHHHgggggg...",
	"..gggggg>HE333H<gggggg..",
	".ggggggg>HHHHHH<gggggg..",
	".ggggggggHHHHHHgggggg...",
	"...ggggggHHHHHH.........",
	"....ggggggggg.......ggg.",
	".....ggg............ggg.",
]

func _ready() -> void:
	var rows: Array = []
	var biomes := [{"id":"meadow","level":1,"region":{"x":80,"y":80,"cells":[]}},{"id":"forest","level":2,"region":{"x":80,"y":80,"cells":[]}},{"id":"mountain","level":3,"region":{"x":80,"y":80,"cells":[]}}]
	for y in T.SIZE:
		var bytes := PackedByteArray()
		bytes.resize(T.SIZE)
		bytes.fill(T.SEA)
		var line := y-47
		if line >= 0 and line < MAP.size():
			for x in MAP[line].length():
				var mark: String = MAP[line][x]
				if mark == ".": continue
				var k: int = {"g":T.LOW,"H":T.HIGH,"3":T.SUMMIT,"E":T.UPPER_EAST,">":T.EAST,"<":T.WEST}[mark]
				bytes[x+41] = k
				var cell := {"x":x-11,"y":line-5}
				var level := T.level(k)
				biomes[level-1].region.cells.append(cell)
				for lower in range(level-1):
					if lower == 0 and line == 7 and x >= 13: continue
					var region: Dictionary = biomes[lower].region
					if not region.has("covered"): region.covered = []
					region.covered.append(cell)
		rows.append(bytes.get_string_from_ascii())
	$Surface.build({"terrain":rows,"biomes":biomes,"seed":"reference"})
	$Camera.terrain = rows
	$Camera.zoom = 0.31
	$Camera.apply_transform()
	for pair in [[$Totem,Vector2i(46,51)],[$Minion,Vector2i(48,51)],[$Sheep,Vector2i(52,51)]]:
		pair[0].position = View.world(T.center(pair[1]),rows)
	$Totem.position.y += 2.0
