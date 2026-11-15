shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

uniform vec4 shadow_color : source_color = vec4(0.10, 0.12, 0.16, 1.0);
uniform float opacity : hint_range(0.0, 0.12, 0.01) = 0.12;
uniform float soft_edge : hint_range(0.05, 1.0, 0.05) = 0.55;

void fragment() {
	float radius = length(UV * 2.0 - 1.0);
	float mask = 1.0 - smoothstep(1.0 - soft_edge, 1.0, radius);
	ALBEDO = shadow_color.rgb;
	ALPHA = mask * opacity * shadow_color.a;
}
