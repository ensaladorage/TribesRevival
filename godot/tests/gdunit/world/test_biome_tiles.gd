extends GdUnitTestSuite

const CATALOG := "res://assets/biomes/recortes"
const SHEETS := "res://assets/biomes/Tileset"

func test_atlas_crops_cover_visible_source_pixels() -> void:
	var remainder := {}
	for name in DirAccess.get_files_at(SHEETS):
		if name.ends_with(".png"):
			var path := SHEETS.path_join(name)
			remainder[path] = _source_image(path)
	_check_crops(CATALOG, remainder)
	for path in remainder:
		var sheet: Image = remainder[path]
		assert_that(sheet.get_used_rect()).override_failure_message(path + ": missing visible pixels").is_equal(Rect2i())

func _check_crops(folder: String, remainder: Dictionary) -> void:
	for name in DirAccess.get_files_at(folder):
		if not name.ends_with(".tres"):
			continue
		var tile := load(folder.path_join(name)) as AtlasTexture
		assert_that(tile).is_not_null()
		if tile == null:
			continue
		assert_that(tile.atlas).is_not_null()
		if tile.atlas == null:
			continue
		var source: Image = remainder[tile.atlas.resource_path]
		var rect := Rect2i(tile.region)
		assert_bool(rect.has_area() and Rect2i(Vector2i.ZERO, source.get_size()).encloses(rect)).is_true()
		source.fill_rect(rect, Color.TRANSPARENT)
	for child in DirAccess.get_directories_at(folder):
		_check_crops(folder.path_join(child), remainder)

func test_active_biomes_use_flat_tiles_with_opaque_spawn_centers() -> void:
	for name in ["Clearing", "Meadow", "Forest", "Rocky", "Ruins", "Mountain"]:
		var scene: PackedScene = load("res://scenes/world/Biome%s.tscn" % name)
		var patch: Node3D = auto_free(scene.instantiate())
		assert_int(patch.ground_tiles.size()).is_equal(16)
		for tile: AtlasTexture in patch.ground_tiles:
			assert_bool(tile.resource_path.contains("/suelo/")).is_true()
			assert_that(tile.region.size).is_equal(Vector2(64, 64))
			var source := _source_image(tile.atlas.resource_path)
			var center := source.get_region(Rect2i(tile.region).grow(-16))
			assert_int(center.detect_alpha()).is_equal(Image.ALPHA_NONE)

func _source_image(path: String) -> Image:
	var source := Image.new()
	assert_int(source.load_png_from_buffer(FileAccess.get_file_as_bytes(path))).is_equal(OK)
	return source
