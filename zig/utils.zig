pub fn length(vec: @Vector(2, f32)) f32 {
    return @sqrt(vec[0] * vec[0] + vec[1] * vec[1]);
}
