extends Node
## Play this scene with F6 to inspect the climb with the real controls and AI.
@export var review_seed := "relieve-000"
@export var show_vegetation := false

func _ready() -> void:
	call_deferred("_open_review")

func _open_review() -> void:
	var game = get_parent()
	var state: Dictionary = game.Session.State.create_initial(review_seed)
	state.barbarians.clear()
	state.animals.clear()
	if not show_vegetation:
		state.decorations.clear()
		var destination: String = state.biomes[2].instanceId
		state.resources = state.resources.filter(func(node): return node.biomeInstanceId == destination)
	for i in range(2,8):
		var point := Vector2(80,80)+Vector2.from_angle(TAU*i/8)*4
		state.units.append(game.Session.State.create_unit("review-%d" % i,"artisan" if i == 2 else "gatherer",{"x":point.x,"y":point.y}))
	game._replace_state(state)
	game.menus.show_game()
