extends Node3D
## Screen-space badge driven only by an existing alert's age and position.

@export var anchor_height := 2.1
@export var screen_offset := Vector2(-11, -13)

func present(point: Vector3, progress: float) -> void:
	position = point
	var camera := get_viewport().get_camera_3d()
	$Overlay.visible = camera != null and not camera.is_position_behind(point)
	if $Overlay.visible:
		$Overlay/Badge.position = camera.unproject_position(point + Vector3(0, anchor_height, 0)) + screen_offset
		$Overlay/Badge.modulate.a = clampf(1.0 - progress, 0, 1)
