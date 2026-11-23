shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

uniform sampler2D sprite_texture : source_color, filter_nearest, repeat_disable;
uniform vec4 circles[32];
uniform int circle_count = 0;
uniform float dither_pixel_size = 2.0;
uniform bool standing = false;
#include "res://shaders/standing_depth.gdshaderinc"

void fragment() {
	vec4 tex = texture(sprite_texture, UV);
	if (tex.a < 0.5) { discard; }
	float keep = 1.0;
	for (int i = 0; i < circle_count; i++) {
		float distance_to_center = distance(view_position, circles[i].xy);
		keep = min(keep, smoothstep(circles[i].z, circles[i].z + max(circles[i].w, 0.0001), distance_to_center));
	}
	// Ordered 4x4 Bayer pattern. The center is absent, the exterior fully opaque.
	const float bayer[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	ivec2 pixel = ivec2(mod(floor(FRAGCOORD.xy / dither_pixel_size), 4.0));
	float threshold = (bayer[pixel.y * 4 + pixel.x] + 0.5) / 16.0;
	if (keep < threshold) { discard; }
	DEPTH = standing ? sprite_depth(FRAGCOORD.z, PROJECTION_MATRIX[2][2]) : FRAGCOORD.z;
	ALBEDO = tex.rgb * COLOR.rgb;
}
