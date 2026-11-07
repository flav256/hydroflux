shader_type canvas_item;
render_mode blend_mix;

// Luminous cavern behind black silhouettes. Contre-Jour reads as
// light seen through a cut in solid black, not gray shapes on black.

uniform vec3 deep_color : source_color = vec3(0.012, 0.02, 0.03);
uniform vec3 mist_color : source_color = vec3(0.0, 0.22, 0.28);
uniform vec3 heart_color : source_color = vec3(0.25, 0.78, 0.82);
uniform vec2 glow_center = vec2(0.38, 0.46);
uniform float caustic_strength : hint_range(0.0, 0.25) = 0.13;
// Rooms run dim: the light a room has is the light the water carries.
uniform float ambient : hint_range(0.0, 1.0) = 1.0;
uniform vec3 wall_albedo : source_color = vec3(0.16, 0.42, 0.48);

void fragment() {
	vec2 uv = UV;
	vec2 p = (uv - glow_center) * vec2(1.25, 1.05);
	float d = length(p);
	float haze = exp(-d * 2.1);
	float heart = exp(-d * 7.0);
	vec2 q = (uv - vec2(0.72, 0.58)) * vec2(1.4, 1.2);
	float well = exp(-length(q) * 5.5);
	vec3 col = deep_color;
	col += mist_color * haze;
	col += heart_color * heart * 0.62;
	col += heart_color * well * 0.28;
	// Slow, broad caustic traces keep the cavern light alive without busy noise.
	float wave_x = sin(uv.x * 15.0 + sin(uv.y * 8.0 + TIME * 0.14) * 1.15 + TIME * 0.10);
	float wave_y = sin(uv.y * 17.0 + sin(uv.x * 6.0 - TIME * 0.12) * 1.05 - TIME * 0.08);
	float caustic = pow(max(wave_x * wave_y, 0.0), 7.0);
	float caustic_mask = 1.0 - smoothstep(0.18, 0.92, d);
	col += heart_color * caustic * caustic_mask * caustic_strength;
	float shaft = pow(max(sin(uv.x * 3.8 + uv.y * 5.4 + sin(uv.y * 7.0 - TIME * 0.08)), 0.0), 12.0);
	col += mist_color * shaft * haze * 0.12;
	float vignette = smoothstep(1.05, 0.28, length((uv - vec2(0.5)) * vec2(1.2, 0.95)));
	col *= mix(0.25, 1.0, vignette);
	COLOR = vec4(col * ambient, 1.0);
}

// The far wall gives back passing light by its own albedo, so a dim room
// still shows the drop's light and the shadows the rock casts.
void light() {
	LIGHT = vec4(LIGHT_COLOR.rgb * wall_albedo * LIGHT_ENERGY, LIGHT_COLOR.a);
}
