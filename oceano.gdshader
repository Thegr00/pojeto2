shader_type spatial;
render_mode specular_toon; // Gives it a nice anime/stylized shine

// These 'uniforms' will show up as sliders in your Inspector!
uniform vec3 water_color : source_color = vec3(0.0, 0.6, 0.9);
uniform float wave_height = 0.09;
uniform float wave_frequency = 0.7;
uniform float wave_speed = 0.5;

void vertex() {
	// This math creates rolling waves across the X and Z axes
	float height1 = sin(VERTEX.x * wave_frequency + TIME * wave_speed) * wave_height;
	float height2 = cos(VERTEX.z * wave_frequency * 0.8 + TIME * wave_speed * 0.7) * wave_height * 0.5;
	
	// Apply the math to push the water up and down
	VERTEX.y += height1 + height2;
}

void fragment() {
	ALBEDO = water_color;
	ROUGHNESS = 0.6; // Makes the water glossy
	SPECULAR = 0.1;  // <--- ADD THIS LINE! It completely hides the sun dot.
}