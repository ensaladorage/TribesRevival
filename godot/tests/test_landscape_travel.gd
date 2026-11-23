extends SceneTree
## Batch live-session traversal. Optional arguments select a half-open seed range.
const Session = preload("res://scripts/simulation/game_session.gd")
const T = preload("res://scripts/simulation/island_terrain.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var first := int(args[0]) if args.size() >= 2 else 0
	var last := int(args[1]) if args.size() >= 2 else 64
	var failures := 0
	for i in range(first,last):
		var seed_text := "relieve-%03d" % i
		for count in [1,8]:
			var session := Session.new(seed_text)
			var state := session.state
			state.barbarians.clear()
			state.animals.clear()
			var terrace: Dictionary = state.biomes[2]
			state.resources = state.resources.filter(func(n): return n.biomeInstanceId == terrace.instanceId)
			state.units.clear()
			for j in count:
				var point := Vector2(80,80)+Vector2.from_angle(TAU*j/count)*4
				state.units.append(Session.State.create_unit(str(j),"artisan",{"x":point.x,"y":point.y}))
			var success := true
			for destination: Dictionary in [terrace.region,{"x":80,"y":80}]:
				var target := {"x":destination.x,"y":destination.y}
				session.enqueue({"type":"pick-up-totem"})
				session.enqueue({"type":"drag-totem","position":target})
				session.enqueue({"type":"drop-totem"})
				session.flush_actions()
				var arrived := false
				for tick in 1600:
					session.advance(Session.FIXED_DT)
					var uphill := destination.has("cells")
					if state.totem.moving: continue
					if not state.units.all(func(u): return T.fraction(state.terrain,u.position) == (1.0 if uphill else 0.0) and Session.Movement.Geo.distance(u.position,target) <= 10.5): continue
					if uphill and state.inventory.amounts.stone == 0: continue
					arrived = true
					break
				if not arrived:
					success = false
					break
			print("%s %d units %d ticks %s" % [seed_text,count,state.tick,success])
			if not success: failures += 1
	quit(int(failures > 0))
