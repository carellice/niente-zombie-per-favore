shader_type canvas_item;
render_mode unshaded;

varying float vertex_alpha;

void vertex() {
	vertex_alpha = COLOR.a;
}

void fragment() {
	// Flatten the assembled painted actor to white without changing its alpha.
	COLOR = vec4(vec3(1.0), texture(TEXTURE, UV).a * vertex_alpha);
}
