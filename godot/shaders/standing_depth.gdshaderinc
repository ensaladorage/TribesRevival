varying vec2 view_position;
varying float standing_height;
varying flat float depth_slope;

void vertex() {
	vec3 scale = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * scale.x, INV_VIEW_MATRIX[1] * scale.y, INV_VIEW_MATRIX[2] * scale.z, MODEL_MATRIX[3]);
	standing_height = VERTEX.y * scale.y;
	depth_slope = INV_VIEW_MATRIX[2].y / max(INV_VIEW_MATRIX[1].y, 0.001);
	view_position = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xy;
}

// Orthographic projection. Above the pivot, each texel occupies a vertical
// plane. Below it, retain the original ground contact and footprint.
float sprite_depth(float original_depth, float projection_z) {
	float shift = projection_z * max(standing_height, 0.0) * depth_slope;
	return original_depth + shift / (1.0 - CLIP_SPACE_FAR);
}
