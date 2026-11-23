class_name TribeSession
extends RefCounted
## Fixed-step driver. No scene, mesh, Input, camera, or UI dependencies.

const State = preload("res://scripts/simulation/game_state.gd")
const Movement = preload("res://scripts/simulation/minion_movement.gd")
const Work = preload("res://scripts/simulation/work_system.gd")
const Conflict = preload("res://scripts/simulation/conflict_system.gd")
const Survival = preload("res://scripts/simulation/survival_system.gd")
const Weather = preload("res://scripts/simulation/weather_system.gd")
const Commands = preload("res://scripts/simulation/commands.gd")
const FIXED_DT := 1.0 / 20.0
const MAX_STEPS_PER_FRAME := 4

var state: Dictionary
var speed_multiplier := 1
var accumulator := 0.0
var previous_positions := {}
var _actions: Array[Dictionary] = []

func _init(seed_text: String = State.DEFAULT_SEED) -> void:
	state = State.create_initial(seed_text)
	_capture_positions()

func _capture_positions() -> void:
	previous_positions.clear()
	for actor in state.units + state.barbarians + state.animals + state.weather.clouds:
		# A respawn starts a new visible lifetime; never interpolate from death.
		if not actor.get("isAlive", true):
			continue
		previous_positions[actor.id] = actor.position.duplicate()

func enqueue(action: Dictionary) -> void:
	_actions.append(action.duplicate(true))

func flush_actions() -> void:
	for action in _actions:
		_apply_action(action)
	_actions.clear()
	_capture_positions()

func replace_state(next_state: Dictionary) -> void:
	state = next_state.duplicate(true)
	_actions.clear()
	accumulator = 0.0
	speed_multiplier = 1
	_capture_positions()

func advance(frame_seconds: float) -> void:
	accumulator = minf(accumulator + minf(frame_seconds, 0.25) * speed_multiplier, FIXED_DT * MAX_STEPS_PER_FRAME)
	var steps := 0
	while accumulator >= FIXED_DT and steps < MAX_STEPS_PER_FRAME:
		_capture_positions()
		for action in _actions:
			_apply_action(action)
		_actions.clear()
		if state.units.is_empty() and state.phase != "victory":
			state.phase = "defeat"
		if state.phase not in ["paused", "victory"]:
			state.tick += 1
			if state.phase == "defeat":
				Conflict.update_hunter_shots(state)
				Survival.age_effects(state, FIXED_DT)
			else:
				Weather.update(state, FIXED_DT)
				for unit in state.units:
					var pickup_lock_ticks := int(unit.get("pickupLockTicks", 0))
					if pickup_lock_ticks > 1:
						unit.pickupLockTicks = pickup_lock_ticks - 1
					elif pickup_lock_ticks == 1:
						unit.erase("pickupLockTicks")
				Survival.update_cooldowns(state, FIXED_DT)
				var frame := Movement.create_frame(state, FIXED_DT)
				Conflict.update(state, FIXED_DT, frame)
				Work.update_tribe(state, FIXED_DT, frame)
				Movement.resolve_spacing(state)
				Conflict.update_hunter_shots(state)
				Survival.update_campfires(state, FIXED_DT)
				Survival.age_effects(state, FIXED_DT)
		accumulator -= FIXED_DT
		steps += 1

func _apply_action(action: Dictionary) -> void:
	if action.type == "sacrifice-minion":
		var held: Variant = Commands.Carry.held_unit(state)
		Commands.apply(state, action)
		if held != null and held.id == action.unitId and not held.get("isCarried", false):
			# A rejected sacrifice relocates instantly. Ground movement starts here.
			previous_positions[held.id] = held.position.duplicate()
		return
	Commands.apply(state, action)
