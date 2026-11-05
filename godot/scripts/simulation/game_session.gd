class_name TribeSession
extends RefCounted
## Fixed-step driver. No scene, mesh, Input, camera, or UI dependencies.

const State = preload("res://scripts/simulation/game_state.gd")
const FIXED_DT := 1.0 / 20.0
const MAX_STEPS_PER_FRAME := 4

var state: Dictionary
var speed_multiplier := 1
var accumulator := 0.0
var _actions: Array[Dictionary] = []

func _init(seed_text: String = State.DEFAULT_SEED) -> void:
	state = State.create_initial(seed_text)

func enqueue(action: Dictionary) -> void:
	_actions.append(action.duplicate(true))

func advance(frame_seconds: float) -> void:
	accumulator = minf(accumulator + minf(frame_seconds, 0.25) * speed_multiplier, FIXED_DT * MAX_STEPS_PER_FRAME)
	var steps := 0
	while accumulator >= FIXED_DT and steps < MAX_STEPS_PER_FRAME:
		for action in _actions:
			_apply_action(action)
		_actions.clear()
		if state.phase == "playing":
			state.tick += 1
		accumulator -= FIXED_DT
		steps += 1

func _apply_action(action: Dictionary) -> void:
	if action.type == "toggle-pause":
		if state.phase == "playing":
			state.phase = "paused"
		elif state.phase == "paused":
			state.phase = "playing"
		return
	if state.phase != "playing":
		return
	var totem: Dictionary = state.totem
	match action.type:
		"pick-up-totem":
			if totem.isCarried:
				return
			totem.isCarried = true
			totem.moving = false
			totem.destination = null
			totem.dragTarget = totem.position.duplicate()
		"drag-totem":
			if totem.isCarried:
				totem.position = State.clamp_position(action.position)
				totem.dragTarget = totem.position.duplicate()
		"drop-totem":
			if totem.isCarried:
				totem.isCarried = false
				totem.moving = true
				totem.destination = null
				totem.dragTarget = null
