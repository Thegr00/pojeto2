shader_type canvas_item;

// This grabs the pixels of the game rendering directly behind the ColorRect
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

void fragment() {
    // Get the original color of the screen at this exact pixel
    vec4 original_color = texture(screen_texture, SCREEN_UV);
    
    // Calculate the grayscale value using standard human-eye luminosity math
    float gray = dot(original_color.rgb, vec3(0.299, 0.587, 0.114));
    
    // Apply the new black and white color to the screen!
    COLOR = vec4(gray, gray, gray, original_color.a);
}