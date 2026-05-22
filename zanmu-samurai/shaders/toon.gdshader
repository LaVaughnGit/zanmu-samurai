shader_type spatial;
render_mode specular_disabled;

uniform vec4 albedo : source_color = vec4(1.0);

void fragment() {
	ALBEDO = albedo.rgb;
}

void light() {
	float NdotL = dot(NORMAL, LIGHT);
	// Smooth transition band so shadow edges don't look arbitrary
	float lit = smoothstep(0.0, 0.35, NdotL);
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * lit;
}
