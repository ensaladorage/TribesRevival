@tool
extends "res://scripts/view/world_element.gd"
## Local circular cutouts; opaque exterior and depth-tested dither edge.
@export_group("Canopy occlusion")
## Disable to keep this scene opaque even when it covers a character.
@export var dither_enabled := true:
	set(value):
		dither_enabled = value
		if not value and is_node_ready():
			_holes.clear()
			var sprite := canopy_sprite()
			if sprite != null:
				sprite.material_override = null
## Normalized texture coordinates, origin at top left; transparent pixels excluded.
@export var canopy_region := Rect2(0.08, 0.04, 0.84, 0.78)
## Low shrubs reveal only the part of the body actually behind their foliage.
@export var center_on_overlap := false
@export_range(0.05, 5.0, 0.05) var hole_radius := 1.15
@export_range(0.05, 2.0, 0.05) var dither_edge_width := 0.5
@export_range(1.0, 4.0, 1.0) var dither_pixel_size := 2.0
@export_range(0.01, 2.0, 0.01) var fade_out_seconds := 0.15
@export_range(0.01, 2.0, 0.01) var fade_in_seconds := 0.25
@export_range(0.0, 1.0, 0.01) var restore_delay_seconds := 0.15
const DITHER_SHADER = preload("res://shaders/tree_dither.gdshader")
const MAX_HOLES := 32
var _holes := {}
var _material: ShaderMaterial

func canopy_sprite() -> SpriteBase3D:
	var container: Node3D = _replacement if is_instance_valid(_replacement) else $Visual/Default
	for child in container.find_children("*", "SpriteBase3D", true, false):
		if child.is_visible_in_tree():
			return child as SpriteBase3D
	return null

func update_holes(targets: Dictionary, camera: Camera3D, delta: float) -> void:
	if not dither_enabled:
		return
	var sprite := canopy_sprite()
	if sprite == null:
		return
	for id in targets:
		if not _holes.has(id) and _holes.size() < MAX_HOLES:
			_holes[id] = {"center": targets[id], "amount": 0.0, "clear": 0.0}
		if _holes.has(id):
			_holes[id].center = targets[id]
	for id in _holes.keys():
		var hole: Dictionary = _holes[id]
		if targets.has(id):
			hole.clear = 0.0
			hole.amount = move_toward(hole.amount, 1.0, delta / fade_out_seconds)
		else:
			var delay := maxf(0.0, restore_delay_seconds - hole.clear)
			hole.clear += delta
			hole.amount = move_toward(hole.amount, 0.0, maxf(0.0, delta - delay) / fade_in_seconds)
		if hole.amount <= 0:
			_holes.erase(id)
	if _holes.is_empty():
		sprite.material_override = null
		return
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = DITHER_SHADER
	var circles := PackedVector4Array()
	circles.resize(MAX_HOLES)
	var index := 0
	for hole in _holes.values():
		var center: Vector3 = camera.to_local(hole.center)
		circles[index] = Vector4(center.x, center.y, hole_radius * hole.amount, dither_edge_width * hole.amount)
		index += 1
	var texture: Texture2D
	if sprite is AnimatedSprite3D:
		texture = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	elif sprite is Sprite3D:
		texture = sprite.texture
	# Sprite geometry already contains the atlas UV region of the current frame.
	_material.set_shader_parameter("sprite_texture", texture.atlas if texture is AtlasTexture else texture)
	_material.set_shader_parameter("circles", circles)
	_material.set_shader_parameter("circle_count", index)
	_material.set_shader_parameter("dither_pixel_size", dither_pixel_size)
	sprite.material_override = _material
