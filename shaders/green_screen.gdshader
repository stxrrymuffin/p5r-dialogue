shader_type canvas_item;

uniform vec3 key_color : source_color = vec3(0.071, 1.0, 0.176);
uniform float threshold : hint_range(0.0, 1.0) = 0.618;
uniform float smoothing : hint_range(0.0, 1.0) = 0.561;

void fragment() {

    vec4 current_color = texture(TEXTURE, UV);
    float mask = distance(current_color.rgb, key_color.rgb);
    float alpha = smoothstep(threshold, threshold + smoothing, mask);

    COLOR = vec4(current_color.rgb, current_color.a * alpha);
}