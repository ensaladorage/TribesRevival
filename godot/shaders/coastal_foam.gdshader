shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform sampler2D frames : source_color, filter_nearest, repeat_disable;
void fragment() {
	float frame = mod(floor(TIME * 10.0) + round(COLOR.r * 15.0), 16.0);
	vec4 pixel = texture(frames, vec2((frame + UV.x) / 16.0, UV.y));
	ALBEDO = pixel.rgb;
	ALPHA = pixel.a;
}
