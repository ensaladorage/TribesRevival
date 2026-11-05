extends SceneTree
## Native input-dispatch regression. No game scene, rendering or simulation ticks.

class InputProbe extends "res://scripts/main.gd":
	var releases := 0
	func _ready() -> void:
		# Entry-point input only; no world/HUD construction or user saves.
		world_view.free()
		hud.free()
		menus.free()
	func _process(_delta: float) -> void:
		pass
	func _unhandled_input(_event: InputEvent) -> void:
		pass
	func _finish_placement() -> void:
		releases += 1
		held_item = ""

var failures: Array[String] = []
var starts := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var probe := InputProbe.new()
	var camera := Camera3D.new()
	camera.name = "Camera3D"
	probe.add_child(camera)
	var totem := MeshInstance3D.new()
	totem.name = "Totem"
	probe.add_child(totem)
	root.add_child(probe)
	var button := Button.new()
	button.position = Vector2(10, 10)
	button.size = Vector2(120, 40)
	root.add_child(button)
	button.button_down.connect(func():
		starts += 1
		probe.held_item = "gatherer")
	# Use real engine dispatch and the inherited main._input, not signal.emit.
	for attempt in range(1, 5):
		var motion := InputEventMouseMotion.new()
		motion.position = Vector2(20, 20)
		root.push_input(motion, true)
		var down := InputEventMouseButton.new()
		down.position = motion.position
		down.button_index = MOUSE_BUTTON_LEFT
		down.pressed = true
		root.push_input(down, true)
		var up := down.duplicate()
		up.pressed = false
		root.push_input(up, true)
		if starts != attempt or probe.releases != attempt or button.button_pressed:
			failures.append("Attempt %s: starts=%s, releases=%s, pressed=%s" % [attempt, starts, probe.releases, button.button_pressed])
	button.free()
	probe.free()
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("PASS placement input: 4 consecutive presses/releases through main._input; no rendering or gameplay")
	quit(0 if failures.is_empty() else 1)
