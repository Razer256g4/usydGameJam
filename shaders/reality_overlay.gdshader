shader_type canvas_item;
// Full-screen post-process sold purely as an overlay (no screen-texture read, so it works
// on every renderer incl. GL Compatibility / web). Hud drives `intensity` from the current
// reality state: clean when stable, grainy/red as the truth leaks through.

uniform float intensity : hint_range(0.0, 1.0) = 0.32;
uniform float vignette_strength : hint_range(0.0, 2.0) = 1.15;
uniform vec4 tint : source_color = vec4(0.0, 0.0, 0.0, 1.0);

float rand(vec2 c) {
	return fract(sin(dot(c, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	// vignette: 1.0 at centre -> 0.0 at the corners
	float d = distance(uv, vec2(0.5));
	float vig = smoothstep(0.85, 0.35, d);
	float dark = (1.0 - vig) * vignette_strength;

	// scanlines + animated grain scale with how unstable reality is
	float scan = sin(uv.y * 720.0) * 0.05 * intensity;
	float grain = (rand(uv * (1.0 + floor(TIME * 12.0))) - 0.5) * 0.18 * intensity;

	float a = clamp(dark + scan + grain, 0.0, 1.0);

	// truth bleeds red into the edges the further reality slips
	vec3 col = tint.rgb + vec3(0.30, 0.0, 0.02) * (1.0 - vig) * intensity;
	COLOR = vec4(col, a);
}
