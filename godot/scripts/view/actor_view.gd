@tool
extends Node3D
## Presentation only. SpriteFrames, transforms, selection shape and tools live in scenes.

@export var visual_scale := Vector3.ONE:
	set(value):
		visual_scale = value
		if is_node_ready():
			$Body.scale = value
@export var visual_tint := Color.WHITE:
	set(value):
		visual_tint = value
		if is_node_ready():
			$Body/Sprite.modulate = value
@export var health_screen_margin_pixels := 18.0
@export var show_health := true
var _health_position := Vector3.ZERO
var _rest_position := Vector3.ZERO

func _ready() -> void:
	_rest_position = $Body.position
	_health_position = $Health.position
	$Body.scale = visual_scale
	$Body/Sprite.modulate = visual_tint

func present(actor: Dictionary) -> void:
	var sprite: AnimatedSprite3D = $Body/Sprite
	var animation := "idle"
	if actor.get("task", {}).get("kind", "") == "combat":
		animation = "attack"
	elif actor.get("state", "") in ["working", "gathering"]:
		animation = "work"
	elif actor.has("navigation") and Vector2(actor.navigation.velocity.x, actor.navigation.velocity.y).length_squared() > 1e-8:
		animation = "move"
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(animation):
		if sprite.animation != animation or not sprite.is_playing():
			sprite.play(animation)
	$Shield.visible = actor.get("hasShield", false)

func reset_feedback() -> void:
	$Body.position = _rest_position
	$Body/Sprite.modulate = visual_tint

func flash(color: Color) -> void:
	$Body/Sprite.modulate = color

func lunge(direction: Vector3, amount: float) -> void:
	$Body.position += direction * amount

func pick_ray(origin: Vector3, direction: Vector3) -> Variant:
	# Same math-only picking as before, using the scene's editable box shape.
	var shape: CollisionShape3D = $Selection/Shape
	var box := shape.shape as BoxShape3D
	var hit: Variant = AABB(-box.size / 2.0, box.size).intersects_ray(shape.to_local(origin), shape.global_basis.inverse() * direction)
	return shape.to_global(hit) if hit is Vector3 else null

func present_health(actor: Dictionary, _pixel_size: float, _screen_up: Vector3) -> void:
	var camera := get_viewport().get_camera_3d()
	$HealthDisplay.visible = show_health and camera != null and not camera.is_position_behind(global_position)
	if not $HealthDisplay.visible:
		return
	var screen := camera.unproject_position(to_global(_health_position)) - Vector2(0, health_screen_margin_pixels)
	$HealthDisplay.present(int(ceil(maxf(actor.health, 0))), int(ceil(actor.maxHealth)), screen)
