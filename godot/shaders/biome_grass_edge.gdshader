shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D grass : source_color, filter_nearest, repeat_disable;
void fragment() {
	vec2 tile = fract(UV * vec2(textureSize(grass, 0)) / 64.0);
	int side = int(round(COLOR.g * 3.0));
	float along = side < 2 ? tile.y : tile.x;
	float across = side == 0 ? tile.x : (side == 1 ? 1.0-tile.x : (side == 2 ? tile.y : 1.0-tile.y));
	float pixel = floor(along * 64.0);
	float fringe = (5.0 + 2.0 * sin(pixel * 0.24) + 2.0 * sin(floor(pixel / 2.0) * 1.8)) / 64.0;
	if (across > fringe || along < 0.07 || along > 0.93) { discard; }
	ALBEDO = texture(grass, UV).rgb;
}
