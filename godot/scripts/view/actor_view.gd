@tool
extends Node3D
## Presentation only. SpriteFrames, transforms and selection shape live in scenes.

const FACING_DEAD_ZONE := 0.0001

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
@export var carried_height := 2.6
@export var use_attack_events := false
var _health_position := Vector3.ZERO
var _rest_position := Vector3.ZERO
var _carried := false
var _right_flip_h := false
var _last_attack_effect := ""

func _ready() -> void:
	_right_flip_h = $Body/Sprite.flip_h
	_rest_position = $Body.position
	_health_position = $Health.position
	$Body.scale = visual_scale
	$Body/Sprite.modulate = visual_tint

func present(actor: Dictionary, is_moving: bool, horizontal: float = 0.0, graze_frame: int = -1) -> void:
	_carried = actor.get("isCarried", false)
	reset_feedback()
	var sprite: AnimatedSprite3D = $Body/Sprite
	if not _carried and is_moving and absf(horizontal) > FACING_DEAD_ZONE:
		sprite.flip_h = not _right_flip_h if horizontal < 0.0 else _right_flip_h
	if sprite.sprite_frames == null:
		return
	if use_attack_events and not _carried and sprite.animation == &"attack" and sprite.is_playing():
		return
	if graze_frame >= 0 and sprite.sprite_frames.has_animation(&"graze"):
		sprite.animation = &"graze"
		sprite.pause()
		sprite.set_frame_and_progress(graze_frame, 0.0)
		return
	var animation: StringName = &"idle"
	if not _carried:
		if not use_attack_events and actor.get("task", {}).get("kind", "") == "combat" and sprite.sprite_frames.has_animation(&"attack"):
			animation = &"attack"
		elif actor.get("state", "") in ["working", "gathering"] and sprite.sprite_frames.has_animation(&"work"):
			animation = &"work"
		elif is_moving and sprite.sprite_frames.has_animation(&"move"):
			animation = &"move"
	if sprite.sprite_frames.has_animation(animation) and (sprite.animation != animation or not sprite.is_playing()):
		sprite.play(animation)

func present_attack(effect_id: String) -> bool:
	if not use_attack_events or _carried or effect_id == _last_attack_effect:
		return false
	var sprite: AnimatedSprite3D = $Body/Sprite
	if sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(&"attack"):
		return false
	_last_attack_effect = effect_id
	sprite.stop()
	sprite.play(&"attack")
	return true

func present_hunter_draw(animation_frame: float, aim_horizontal: float) -> void:
	if _carried:
		return
	var sprite: AnimatedSprite3D = $Body/Sprite
	if sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(&"attack"):
		return
	if absf(aim_horizontal) > FACING_DEAD_ZONE:
		sprite.flip_h = not _right_flip_h if aim_horizontal < 0.0 else _right_flip_h
	sprite.animation = &"attack"
	sprite.pause()
	var frame_index := mini(floori(animation_frame), sprite.sprite_frames.get_frame_count(&"attack") - 1)
	sprite.set_frame_and_progress(frame_index, clampf(animation_frame - frame_index, 0.0, 1.0))

func reset_feedback() -> void:
	$Body.position = _rest_position + Vector3.UP * (carried_height if _carried else 0.0)
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
	var screen := camera.unproject_position(to_global(_health_position + Vector3.UP * (carried_height if actor.get("isCarried", false) else 0.0))) - Vector2(0, health_screen_margin_pixels)
	$HealthDisplay.present(int(ceil(maxf(actor.health, 0))), int(ceil(actor.maxHealth)), screen, 1 if actor.get("hasShield", false) else 0)
