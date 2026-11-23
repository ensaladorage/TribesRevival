extends SceneTree
const Session = preload("res://scripts/simulation/game_session.gd")
const T = preload("res://scripts/simulation/island_terrain.gd")
const View = preload("res://scripts/view/terrain_projection.gd")
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var session := Session.new("archipelago-travel")
	var state := session.state
	var rows: Array = state.terrain
	var dest: Dictionary = state.biomes[2].region
	var home: Dictionary = state.totem.position.duplicate()
	var goal := {"x":dest.x,"y":dest.y}
	var sea := {"x":2,"y":2}
	var cmd := Session.Commands
	for kind in ["totem","minion"]:
		var actor: Dictionary = state.totem if kind == "totem" else state.units[0]
		for action in [{"type":"pick-up-"+kind},{"type":"drag-"+kind,"position":goal},{"type":"drag-"+kind,"position":sea},{"type":"drop-"+kind}]:
			action.unitId = state.units[0].id
			cmd.apply(state,action)
		check(T.fits(rows,actor.position,0.32,true) and T.fraction(rows,actor.position) == 1.0,"Last valid landing on plateau: "+kind)
	var summit: Dictionary = state.biomes.filter(func(b): return b.level == 3)[0].region
	var walker: Dictionary = home.duplicate()
	var memory := {}
	for destination in [{"x":summit.x,"y":summit.y},home]:
		var used := {}
		for step in 2000:
			var waypoint := T.waypoint(rows,walker,destination,memory)
			var next := walker.duplicate()
			Session.Weather.move_point(next,waypoint,0.12)
			if not T.clear(rows,walker,next): break
			walker = next
			var kind := T.code(rows,T.cell(walker))
			if T.ramp(kind): used[T.level(kind)] = true
			if Session.Movement.Geo.distance(walker,destination) < 0.05: break
		check(used.size() == 2 and Session.Movement.Geo.distance(walker,destination) < 0.05,"Route to summit and back through both stairs")
	var inventory: Dictionary = state.inventory.duplicate()
	cmd.apply(state,{"type":"place-campfire","position":sea})
	cmd.apply(state,{"type":"recruit-gatherer","position":sea})
	check(state.inventory == inventory and state.units.size() == 2 and state.campfires.is_empty(),"Water placement is transactional")
	var unit: Dictionary = state.units[0]
	state.units = [unit]
	state.animals = []
	var enemy: Dictionary = state.barbarians[0]
	state.barbarians = []
	unit.position = home.duplicate()
	unit.task.kind = "return-to-totem"
	var passed_stairs := false
	var target := Session.Movement.formation_target(state,0)
	for i in 1500:
		var prev: Dictionary = unit.position.duplicate()
		var frame := Session.Movement.create_frame(state,0.05)
		Session.Movement.move_towards(state,unit,target,0.3,frame)
		check(T.clear(rows,prev,unit.position),"Minion crossed blocked edge")
		passed_stairs = passed_stairs or T.ramp(T.code(rows,T.cell(unit.position)))
		if Session.Movement.Geo.distance(unit.position,target) < 0.1: break
	check(passed_stairs and Session.Movement.Geo.distance(unit.position,target) < 0.1,"Minion used stairs and arrived at formation slot")
	state.totem.position = home
	enemy.position = goal.duplicate()
	state.units = []
	state.barbarians = [enemy]
	var enemy_goal := {"x":home.x + 4,"y":home.y}
	for i in 1500:
		var prev: Dictionary = enemy.position.duplicate()
		var frame := Session.Movement.create_frame(state,0.05)
		if Session.Conflict._move_barbarian(state,enemy,enemy_goal,0.35,frame): break
		check(T.clear(rows,prev,enemy.position),"Enemy crossed blocked edge")
	check(Session.Movement.Geo.distance(enemy.position,enemy_goal) < 0.2,"Enemy descended and crossed the causeway")
	_check_stair_save()
	_check_stair_traffic()
	_check_wide_stair()
	_check_live_trip_and_fauna()
	var ref := preload("res://scenes/world/TerrainReference.tscn").instantiate()
	root.add_child(ref)
	await process_frame
	_check_wall_tiles(ref.get_node("Surface"))
	var camera: Camera3D = ref.get_node("Camera")
	for c: Vector2i in [Vector2i(53,51),Vector2i(47,51),Vector2i(52,51),Vector2i(49,51),Vector2i(56,51)]:
		var p := T.center(c)
		var pos := View.world(p,camera.terrain)
		var screen := camera.unproject_position(pos)
		var hit: Vector3 = camera.ground_point(screen)
		check(pos.distance_to(hit) < 0.005,"Visible surface picking "+str(c))
	var front := T.center(Vector2i(53,54))
	var wall := View.world(front,camera.terrain)
	wall.z += T.TILE * View.DEPTH_SCALE * 0.49
	wall.y *= 0.5
	check(camera.ground_point(camera.unproject_position(wall)).y < 0,"Vertical wall rejects placement")
	var low := T.center(Vector2i(52, 48))
	var high := T.center(Vector2i(52, 49))
	low.y += 0.38
	high.y -= 0.38
	state.terrain = camera.terrain
	unit.position = low
	enemy.position = high
	unit.role = "guardian"
	var stats := {"cooldownSeconds": 1, "damage": 1}
	var health: float = enemy.health
	Session.Conflict._attack(state, unit, enemy, stats, "barbarian")
	check(enemy.health == health, "Melee hit crossed a cliff")
	unit.role = "hunter"
	Session.Conflict._attack(state, unit, enemy, stats, "barbarian")
	check(enemy.health < health, "Ranged hit failed across elevations")
	ref.free()
	for message in failures.slice(0,8): push_error(message)
	print("Island route and picking failures: ",failures.size())
	quit(int(not failures.is_empty()))

func _check_live_trip_and_fauna() -> void:
	var session := Session.new("archipelago-travel")
	var state := session.state
	state.barbarians.clear()
	var region: Dictionary = state.biomes[2].region
	var goal := {"x": region.x, "y": region.y}
	for action in [{"type":"pick-up-totem"}, {"type":"drag-totem","position":goal}, {"type":"drop-totem"}]:
		session.enqueue(action)
	session.flush_actions()
	var reached := false
	var climbed := false
	var travelled := 0.0
	var valid_walk := true
	var valid_patrol := true
	for tick in 1300:
		var previous_units: Array = state.units.map(func(u): return u.position.duplicate())
		var previous_animals: Array = state.animals.map(func(a): return a.position.duplicate())
		session.advance(Session.FIXED_DT)
		for index in state.units.size():
			var p: Dictionary = state.units[index].position
			valid_walk = valid_walk and T.clear(state.terrain, previous_units[index], p)
			climbed = climbed or T.ramp(T.code(state.terrain, T.cell(p)))
		for index in state.animals.size():
			var animal: Dictionary = state.animals[index]
			var meadow: Dictionary = state.biomes.filter(func(b): return b.instanceId == animal.homeBiomeId)[0]
			var mask := T.meadow_rows(meadow.region, state.terrain)
			if valid_patrol and not T.clear(mask, previous_animals[index], animal.position):
				push_warning("Patrol left %s at tick %d: %s -> %s" % [animal.homeBiomeId,tick,previous_animals[index],animal.position])
				valid_patrol = false
			travelled += Session.Movement.Geo.distance(previous_animals[index], animal.position)
		if not state.totem.moving and state.units.all(func(u): return T.fraction(state.terrain,u.position) == 1.0):
			reached = true
			if tick >= 400: break
	check(reached and climbed and valid_walk, "Tribe failed to regroup on the plateau in a live session")
	check(valid_patrol and travelled > 30.0, "Sheep failed to patrol inside their own meadows, distance %s" % travelled)
	var sheep: Dictionary = state.animals[0]
	sheep.isAlive = false
	sheep.respawnRemainingSeconds = Session.FIXED_DT
	session.advance(Session.FIXED_DT)
	check(sheep.isAlive and sheep.position == sheep.spawnPosition and sheep.spawnCycle == 1, "Sheep failed to respawn at home")

func _check_wall_tiles(surface: MeshInstance3D) -> void:
	var mesh := surface.mesh as ArrayMesh
	var ends := {}
	var buried := false
	var front := T.center(Vector2i(52,54))
	var front_z: float = (front.y + T.TILE/2) * View.DEPTH_SCALE
	for index in mesh.get_surface_count():
		var material := mesh.surface_get_material(index) as StandardMaterial3D
		if material == null or material.albedo_texture not in [surface.palettes.forest,surface.palettes.meadow]: continue
		var arrays := mesh.surface_get_arrays(index)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for tri in range(0,indices.size(),3):
			var a := vertices[indices[tri]]
			var b := vertices[indices[tri+1]]
			var c := vertices[indices[tri+2]]
			var center := (a+b+c)/3
			var cell := T.cell(View.logical(center))
			if material.albedo_texture == surface.palettes.meadow:
				if cell == Vector2i(52,54) and absf(center.y-0.03)<0.005: buried = true
				continue
			if absf(a.z-front_z)>0.005 or absf(b.z-front_z)>0.005 or absf(c.z-front_z)>0.005: continue
			var uv := (uvs[indices[tri]]+uvs[indices[tri+1]]+uvs[indices[tri+2]])/3
			ends[cell.x] = floori(uv.y*material.albedo_texture.get_height()/64)
	check(buried,"Missing base tile below plateau")
	check(ends.get(52) == 4 and ends.get(55) == 5,"One cliff must switch from dry row to water row at its shoreline")

func _check_stair_traffic() -> void:
	var state := Session.new("stair-traffic").state
	var rows := []
	for y in T.SIZE:
		rows.append("1".repeat(50) + (">" if y == 50 else "2") + "2".repeat(54))
	state.terrain = rows
	state.barbarians = []
	state.animals = []
	state.totem.position = T.center(Vector2i(40,40))
	var a: Dictionary = state.units[0]
	var b: Dictionary = state.units[1]
	var west := T.center(Vector2i(47,50))
	var east := T.center(Vector2i(53,50))
	a.position = west.duplicate()
	b.position = east.duplicate()
	for actor in [a,b]:
		actor.task.kind = "return-to-totem"
	for tick in 160:
		state.tick = tick
		var frame := Session.Movement.create_frame(state, 0.05)
		Session.Movement.move_towards(state,a,east,0.2,frame)
		Session.Movement.move_towards(state,b,west,0.2,frame)
		check(Session.Movement.Geo.distance(a.position,b.position) >= 0.9,"Stair users overlapped")
	check(Session.Movement.Geo.distance(a.position,east) < 0.1 and Session.Movement.Geo.distance(b.position,west) < 0.1,"Opposing walkers cleared stair")
	var enemy: Dictionary = Session.new("mixed-traffic").state.barbarians[0]
	state.barbarians = [enemy]
	state.units = [a]
	a.position = west.duplicate()
	enemy.position = east.duplicate()
	for tick in 160:
		state.tick += 1
		var frame := Session.Movement.create_frame(state, 0.05)
		Session.Movement.move_towards(state,a,east,0.2,frame)
		Session.Conflict._move_barbarian(state,enemy,west,0.2,frame)
		check(Session.Movement.Geo.distance(a.position,enemy.position) >= 0.9,"Mixed stair traffic overlapped")
	check(Session.Movement.Geo.distance(a.position,east) < 0.1 and Session.Movement.Geo.distance(enemy.position,west) < 0.1,"Enemy and minion cleared stair")
	state.barbarians = []
	state.units = [a,b]
	a.position = west.duplicate()
	b.position = T.center(Vector2i(46,50))
	for tick in 160:
		state.tick += 1
		var frame := Session.Movement.create_frame(state, 0.05)
		Session.Movement.move_towards(state,a,east,0.2,frame)
		Session.Movement.move_towards(state,b,T.center(Vector2i(52,50)),0.2,frame)
		check(Session.Movement.Geo.distance(a.position,b.position) >= 0.9,"Following stair users overlapped")
	check(T.cell(a.position).x == 53 and T.cell(b.position).x == 52,"Both followers cleared stair")
	var start := T.center(Vector2i(49,44))
	var cliff := T.center(Vector2i(50,44))
	var near := T.center(Vector2i(46,44))
	var drops := [{"id":"cliff","position":cliff,"amount":1},{"id":"near","position":near,"amount":1}]
	var task := Session.Work.Rules.choose_drop_task({"terrain":rows,"unitPosition":start,"drops":drops,"commandRadius":12})
	check(task.targetResourceId == "near","Drop selection accounts for the stair detour")
	state.units = [a]
	state.barbarianCorpses = []
	state.resources = []
	state.drops = [{"id":"cliff","type":"food","position":cliff,"amount":1}]
	a.position = start.duplicate()
	var original_food: float = state.inventory.amounts.food
	Session.Work.set_task(a, Session.Work.choose_work_task(state,a))
	for tick in 300:
		state.tick += 1
		Session.Work.update_unit(state,a,0.05,Session.Movement.create_frame(state,0.05))
		if state.drops.is_empty():
			break
	check(T.fraction(rows,a.position) == 1 and state.inventory.amounts.food == original_food + 1,"Cliff drop collected once from upper level")
	a.position = start.duplicate()
	var node := {"id":"cliff-node","position":cliff,"source":"bush","type":"food","amount":1,"interactionRadius":1.3}
	state.resources = [node]
	Session.Work.set_task(a,Session.Work.choose_work_task(state,a))
	for tick in 300:
		state.tick += 1
		Session.Work.update_unit(state,a,0.05,Session.Movement.create_frame(state,0.05))
		if node.amount == 0:
			break
	check(T.fraction(rows,a.position) == 1 and node.amount == 0,"Cliff node harvested from upper level")
	var sealed := rows.duplicate()
	sealed[50] = sealed[44]
	task = Session.Work.Rules.choose_drop_task({"terrain":sealed,"unitPosition":start,"drops":[drops[0]],"commandRadius":12})
	check(task.kind == "idle","Unreachable drop ignored")
	a.position = T.center(Vector2i(50,50))
	a.erase("stairTicket")
	Session.Work.set_task(a,Session.Work.Rules.idle_task("cancelled"))
	for tick in 24:
		state.tick += 1
		Session.Work.update_unit(state,a,0.05,Session.Movement.create_frame(state,0.05))
		if not T.ramp(T.code(rows,T.cell(a.position))):
			break
	check(not T.ramp(T.code(rows,T.cell(a.position))),"Cancelled worker clears occupied stair without a ticket")

func _check_stair_save() -> void:
	var state := Session.new("stair-save").state
	var stairs := Vector2i(-1,-1)
	for y in state.terrain.size():
		for x in T.SIZE:
			var c := Vector2i(x,y)
			if T.ramp(T.code(state.terrain,c)):
				stairs = c
				break
		if stairs.x >= 0:
			break
	var a: Dictionary = state.units[0]
	var b: Dictionary = state.units[1]
	a.position = T.center(stairs)
	b.position = T.center(stairs + Vector2i.RIGHT)
	var goal := T.center(stairs + Vector2i.LEFT)
	check(T.stair_waypoint(state,b,goal) != goal,"Loaded occupant has priority without ticket")
	var directory := "user://stair-check-%d" % OS.get_process_id()
	var saves := preload("res://scripts/persistence/save_repository.gd").new(directory)
	check(saves.save_slot(1,state).ok,"Save during stair traffic")
	var restored := saves.read_slot(1)
	check(restored.status == "valid","Restore stair traffic")
	if restored.status == "valid":
		var copy: Dictionary = restored.save.gameState
		for replay in [state,copy]:
			for tick in 12:
				replay.tick += 1
				var frame := Session.Movement.create_frame(replay,0.05)
				Session.Movement.move_towards(replay,replay.units[0],goal,0.15,frame)
		check(state.units[0].position == copy.units[0].position,"Deterministic stair movement after reload")
	a.isCarried = true
	check(T.stair_waypoint(state,b,goal) == goal,"Carried occupant releases stair")
	saves.delete_slot(1)
	DirAccess.remove_absolute(directory)

func _check_wide_stair() -> void:
	var state := Session.new("wide-stair").state
	var rows := []
	for y in T.SIZE:
		rows.append("1".repeat(50) + (">" if y in [50,51] else "2") + "2".repeat(54))
	state.terrain = rows
	state.barbarians = []
	state.animals = []
	state.totem.position = T.center(Vector2i(40,40))
	var a: Dictionary = state.units[0]
	var b: Dictionary = state.units[1]
	var west := T.center(Vector2i(47,50))
	var east := T.center(Vector2i(53,51))
	a.position = west.duplicate()
	b.position = east.duplicate()
	var upper := T.center(Vector2i(53,50))
	var lower := T.center(Vector2i(47,51))
	for actor in [a,b]:
		actor.task.kind = "return-to-totem"
	var simultaneous := false
	for tick in 120:
		state.tick = tick
		var frame := Session.Movement.create_frame(state,0.05)
		Session.Movement.move_towards(state,a,upper,0.2,frame)
		Session.Movement.move_towards(state,b,lower,0.2,frame)
		var first := T.cell(a.position)
		var second := T.cell(b.position)
		simultaneous = simultaneous or (first.x == 50 and second.x == 50 and first.y != second.y)
		check(Session.Movement.Geo.distance(a.position,b.position) >= 0.9,"Opposing traffic overlapped on wide stair")
	check(simultaneous and T.cell(a.position).x == 53 and T.cell(b.position).x == 47,"Opposing traffic crossed the wide stair simultaneously")