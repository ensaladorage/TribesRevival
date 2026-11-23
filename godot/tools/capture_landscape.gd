extends SceneTree
## Pass an optional directory containing baseline world JSONs, one per seed.
const State = preload("res://scripts/simulation/game_state.gd")
const TerrainView = preload("res://scripts/view/terrain_projection.gd")
func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.set_process(false)
	var args := OS.get_cmdline_user_args()
	var baseline := not args.is_empty() and args[0] != "candidate"
	var variant := "baseline" if baseline else "candidate"
	var folder := "res://reports/landscape/" + variant
	DirAccess.make_dir_recursive_absolute(folder)
	var indices := [0,17,42]
	if args.size() > 1: indices = [int(args[1])]
	for index in indices:
		var seed_text := "relieve-%03d" % index
		var state := State.create_initial(seed_text)
		if baseline:
			var path := args[0].path_join(seed_text+".json")
			state.merge(JSON.parse_string(FileAccess.get_file_as_string(path)),true)
		main._replace_state(state)
		main.menus.show_game()
		main.menus.hide()
		main.hud.hide()
		main.get_node("Overlay").hide()
		var forest: Dictionary = state.biomes.filter(func(b): return b.id == "forest")[0].region
		var stair := Vector2i.ZERO
		for y in TerrainView.T.SIZE:
			for x in TerrainView.T.SIZE:
				var c := Vector2i(x,y)
				if TerrainView.T.ramp(TerrainView.T.code(state.terrain,c)):
					stair = c
					break
			if stair != Vector2i.ZERO: break
		var shots := {"general":state.totem.position,"claro":state.totem.position,"acceso":TerrainView.T.center(stair),"bosque":forest}
		for shot in shots:
			main.camera.focus = TerrainView.world(shots[shot],state.terrain)
			main.camera.zoom = 2.3 if shot == "general" else 0.5
			main.camera.apply_transform()
			await process_frame
			await RenderingServer.frame_post_draw
			var error := root.get_texture().get_image().save_png(folder.path_join(seed_text+"-"+shot+".png"))
			if error != OK:
				quit(1)
				return
	main.free()
	quit()
