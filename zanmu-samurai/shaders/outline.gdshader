shader_type spatial;
render_mode cull_front, unshaded, shadows_disabled;

uniform float width : hint_range(0.0, 0.1) = 0.03;
uniform vec4 outline_color : source_color = vec4(0.06, 0.04, 0.08, 1.0);

void vertex() {
	vec4 clip_pos = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec4 clip_normal = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX + NORMAL, 1.0);
	vec2 offset = normalize(clip_normal.xy / clip_normal.w - clip_pos.xy / clip_pos.w);
	clip_pos.xy += offset * width * clip_pos.w;
	// Clip the bottom hemisphere of the capsule in local space so the inverted-hull
	// ring never appears at floor level. Capsule local Y runs -0.5..+0.5;
	// the bottom hemisphere occupies -0.5..-0.2, so -0.1 is a safe cut point.
	if (VERTEX.y < -0.1) {
		clip_pos.z = clip_pos.w + 1.0;
	}
	POSITION = clip_pos;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
