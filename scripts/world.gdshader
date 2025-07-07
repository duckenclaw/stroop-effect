shader_type sky;

void sky() {
	// Get screen coordinates and time
	vec3 dir = EYEDIR;
	float time = TIME * 0.5;
	
	// Create multiple layers of swirling patterns
	float pattern1 = sin(dir.x * 8.0 + time) * cos(dir.y * 6.0 + time * 1.2);
	float pattern2 = sin(dir.y * 10.0 - time * 0.8) * cos(dir.z * 4.0 + time * 1.5);
	float pattern3 = sin(length(dir.xy) * 12.0 + time * 2.0);
	
	// Create rotating spiral effect
	float angle = atan(dir.y, dir.x) + time * 0.3;
	float radius = length(dir.xy);
	float spiral = sin(angle * 3.0 + radius * 8.0 - time * 1.5);
	
	// Combine patterns
	float combined = (pattern1 + pattern2 + pattern3 + spiral) * 0.25;
	
	// Create animated color shifts
	vec3 color1 = vec3(
		sin(combined + time) * 0.5 + 0.5,
		sin(combined + time * 1.3 + 2.094) * 0.5 + 0.5,  // 2.094 ≈ 2π/3
		sin(combined + time * 0.7 + 4.188) * 0.5 + 0.5   // 4.188 ≈ 4π/3
	);
	
	// Add secondary color layer with different frequency
	vec3 color2 = vec3(
		cos(combined * 2.0 - time * 0.8) * 0.3 + 0.7,
		cos(combined * 1.5 - time * 1.1 + 1.047) * 0.3 + 0.7,  // π/3
		cos(combined * 2.5 - time * 0.9 + 5.236) * 0.3 + 0.7   // 5π/3
	);
	
	// Blend the colors
	vec3 final_color = mix(color1, color2, sin(time * 0.4) * 0.5 + 0.5);
	
	// Add some brightness variation
	float brightness = (sin(combined * 3.0 + time) * 0.2 + 0.8);
	final_color *= brightness;
	
	// Ensure colors stay in valid range and add slight saturation boost
	final_color = clamp(final_color, 0.0, 1.0);
	final_color = pow(final_color, vec3(0.9)); // Slight gamma adjustment for more vibrant colors
	
	COLOR = final_color;
}
