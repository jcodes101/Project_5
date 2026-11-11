shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

void fragment() {
	vec2 resolution = vec2(textureSize(screen_texture, 0));
	vec2 uv = (floor(SCREEN_UV * resolution / 1.6) + 0.5) * 1.6 / resolution;
	vec3 col = textureLod(screen_texture, uv, 0.0).rgb;
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(luma), 0.09);
	float dither = mod(floor(FRAGCOORD.x) + mod(floor(FRAGCOORD.y), 2.0), 2.0) * 0.008;
	col = floor((col + dither) * 48.0) / 48.0;
	vec2 edge = SCREEN_UV * (1.0 - SCREEN_UV);
	float vignette = clamp(pow(edge.x * edge.y * 16.0, 0.3), 0.0, 1.0);
	col *= mix(0.52, 1.0, vignette);
	COLOR = vec4(col, 1.0);
}
