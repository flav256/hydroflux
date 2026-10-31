shader_type canvas_item;
render_mode blend_mix;

// Luminous cavern behind black silhouettes. Contre-Jour reads as
// light seen through a cut in solid black, not gray shapes on black.

uniform vec3 deep_color : source_color = vec3(0.012, 0.02, 0.03);
uniform vec3 mist_color : source_color = vec3(0.0, 0.22, 0.28);
uniform vec3 heart_color : source_color = vec3(0.25, 0.78, 0.82);
uniform vec2 glow_center = vec2(0.38, 0.46);

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
	float vignette = smoothstep(1.05, 0.28, length((uv - vec2(0.5)) * vec2(1.2, 0.95)));
	col *= mix(0.25, 1.0, vignette);
	COLOR = vec4(col, 1.0);
}
