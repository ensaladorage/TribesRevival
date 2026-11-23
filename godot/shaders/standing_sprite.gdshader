shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;
uniform sampler2D sprite_texture : source_color, filter_nearest, repeat_disable;
#include "res://shaders/standing_depth.gdshaderinc"

void fragment() {
	vec4 pixel = texture(sprite_texture, UV) * COLOR;
	if (pixel.a < 0.5) { discard; }
	DEPTH = sprite_depth(FRAGCOORD.z, PROJECTION_MATRIX[2][2]);
	ALBEDO = pixel.rgb;
}
