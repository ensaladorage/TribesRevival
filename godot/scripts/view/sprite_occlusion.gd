extends RefCounted
## Orthographic billboard geometry and cached opaque samples. No gameplay state.
var _images := {}
var _samples := {}

func texture(sprite: SpriteBase3D) -> Texture2D:
	if sprite is AnimatedSprite3D:
		return sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	if sprite is Sprite3D:
		return sprite.texture
	return null

func image_for(tex: Texture2D) -> Image:
	if tex == null:
		return null
	if not _images.has(tex):
		var image: Image
		if tex is AtlasTexture:
			# AtlasTexture.get_image() cannot crop VRAM-compressed textures.
			var atlas_image := image_for(tex.atlas)
			if atlas_image == null:
				return null
			image = Image.create(int(tex.get_width()), int(tex.get_height()), false, atlas_image.get_format())
			var region: Rect2i = Rect2i(tex.region)
			if region.size == Vector2i.ZERO:
				region.size = atlas_image.get_size()
			image.blit_rect(atlas_image, region, Vector2i(tex.margin.position))
		else:
			image = tex.get_image()
		if image != null and image.is_compressed():
			image.decompress()
		_images[tex] = image
	return _images[tex]

func sprite_point(sprite: SpriteBase3D, uv: Vector2, camera: Camera3D) -> Vector3:
	var rect := sprite.get_item_rect()
	var point := rect.position + Vector2(uv.x, 1.0 - uv.y) * rect.size
	var scale := sprite.global_basis.get_scale().abs()
	return sprite.global_position + camera.global_basis.x * point.x * sprite.pixel_size * scale.x + camera.global_basis.y * point.y * sprite.pixel_size * scale.y

func sprite_samples(sprite: SpriteBase3D, camera: Camera3D) -> PackedVector3Array:
	var tex := texture(sprite)
	var image := image_for(tex)
	var result := PackedVector3Array()
	if image == null or not sprite.is_visible_in_tree():
		return result
	if not _samples.has(tex):
		var points := PackedVector2Array()
		for y in range(0, image.get_height(), 4):
			for x in range(0, image.get_width(), 4):
				if image.get_pixel(x, y).a > 0.5:
					points.append(Vector2((x + 0.5) / image.get_width(), (y + 0.5) / image.get_height()))
		_samples[tex] = points
	# Read scene transforms once per body, not once per opaque sample.
	var rect := sprite.get_item_rect()
	var scale := sprite.global_basis.get_scale().abs()
	var right := camera.global_basis.x * sprite.pixel_size * scale.x
	var up := camera.global_basis.y * sprite.pixel_size * scale.y
	var origin := sprite.global_position
	for raw_uv in _samples[tex]:
		var uv: Vector2 = raw_uv
		if sprite.flip_h:
			uv.x = 1.0 - uv.x
		if sprite.flip_v:
			uv.y = 1.0 - uv.y
		var point := rect.position + Vector2(uv.x, 1.0 - uv.y) * rect.size
		result.append(origin + right * point.x + up * point.y)
	return result

func projected_bounds(points: PackedVector3Array, camera: Camera3D) -> Rect2:
	if points.is_empty():
		return Rect2()
	var right := camera.global_basis.x
	var up := camera.global_basis.y
	var bounds := Rect2(Vector2(points[0].dot(right), points[0].dot(up)), Vector2.ZERO)
	for point in points:
		bounds = bounds.expand(Vector2(point.dot(right), point.dot(up)))
	# Conservative margin: do not lose single samples or touching silhouettes.
	return bounds.grow(0.001)

func sprite_bounds(sprite: SpriteBase3D, camera: Camera3D) -> Rect2:
	return projected_bounds(PackedVector3Array([
		sprite_point(sprite, Vector2.ZERO, camera),
		sprite_point(sprite, Vector2.ONE, camera),
	]), camera)

func covers(sprite: SpriteBase3D, region: Rect2, points: PackedVector3Array, camera: Camera3D) -> bool:
	return covered_point(sprite, region, points, camera) != null

func covered_point(sprite: SpriteBase3D, region: Rect2, points: PackedVector3Array, camera: Camera3D, preferred: Variant = null) -> Variant:
	if points.is_empty() or not sprite.is_visible_in_tree():
		return null
	var closest: Variant = null
	var nearest_distance := INF
	var image: Image
	var rect := sprite.get_item_rect()
	var scale := sprite.global_basis.get_scale().abs()
	var unit := Vector2(scale.x, scale.y) * sprite.pixel_size
	if unit.x <= 0 or unit.y <= 0 or rect.size.x <= 0 or rect.size.y <= 0:
		return null
	for point in points:
		var relative := point - sprite.global_position
		# Positive camera Z is nearer the camera: never fade for a body in front.
		if relative.dot(camera.global_basis.z) >= -0.01:
			continue
		var local := Vector2(relative.dot(camera.global_basis.x), relative.dot(camera.global_basis.y)) / unit
		var uv := (local - rect.position) / rect.size
		uv.y = 1.0 - uv.y
		if not region.has_point(uv):
			continue
		# Do not decode sheets of distant trees that do not overlap any body.
		if image == null:
			image = image_for(texture(sprite))
			if image == null:
				return null
		if sprite.flip_h:
			uv.x = 1.0 - uv.x
		if sprite.flip_v:
			uv.y = 1.0 - uv.y
		var pixel := Vector2i(uv * Vector2(image.get_size()))
		if pixel.x >= 0 and pixel.y >= 0 and pixel.x < image.get_width() and pixel.y < image.get_height() and image.get_pixelv(pixel).a > 0.5:
			if preferred == null:
				return point
			var projected := Vector2(point.dot(camera.global_basis.x), point.dot(camera.global_basis.y))
			var distance := projected.distance_squared_to(preferred)
			if distance < nearest_distance:
				nearest_distance = distance
				closest = point
	return closest
