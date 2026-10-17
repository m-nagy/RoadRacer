shader_type canvas_item;
// Recolors the (red) base car. Only saturated pixels are touched, so windows,
// tyres and shadows keep their look.
uniform float hue_shift = 0.0;
uniform float sat_mul = 1.0;
uniform float val_mul = 1.0;
uniform bool rainbow = false;
uniform float flash : hint_range(0.0, 1.0) = 0.0;

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec3 hsv = rgb2hsv(tex.rgb);
	float amount = smoothstep(0.18, 0.45, hsv.y);
	float h = hue_shift;
	if (rainbow) {
		h = fract(TIME * 0.8);
	}
	vec3 shifted = hsv;
	shifted.x = fract(hsv.x + h);
	shifted.y = clamp(hsv.y * sat_mul, 0.0, 1.0);
	shifted.z = clamp(hsv.z * val_mul, 0.0, 1.0);
	vec3 col = mix(tex.rgb, hsv2rgb(shifted), amount);
	col = mix(col, vec3(1.0), flash);
	COLOR = vec4(col, tex.a);
}
