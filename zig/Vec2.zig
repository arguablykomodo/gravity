x: f32,
y: f32,

const Vec2 = @This();

pub fn new(x: f32, y: f32) Vec2 {
    return Vec2{ .x = x, .y = y };
}

pub fn add(self: Vec2, other: anytype) Vec2 {
    const type_of = @TypeOf(other);
    const type_info = @typeInfo(type_of);
    return if (type_of == Vec2)
        Vec2{ .x = self.x + other.x, .y = self.y + other.y }
    else if (type_info == .Int or type_info == .Float or type_info == .ComptimeInt or type_info == .ComptimeFloat)
        Vec2{ .x = self.x + other, .y = self.y + other }
    else
        @compileError("unsupported type");
}

pub fn sub(self: Vec2, other: anytype) Vec2 {
    const type_of = @TypeOf(other);
    const type_info = @typeInfo(type_of);
    return if (type_of == Vec2)
        Vec2{ .x = self.x - other.x, .y = self.y - other.y }
    else if (type_info == .Int or type_info == .Float or type_info == .ComptimeInt or type_info == .ComptimeFloat)
        Vec2{ .x = self.x - other, .y = self.y - other }
    else
        @compileError("unsupported type");
}

pub fn mul(self: Vec2, other: anytype) Vec2 {
    const type_of = @TypeOf(other);
    const type_info = @typeInfo(type_of);
    return if (type_of == Vec2)
        Vec2{ .x = self.x * other.x, .y = self.y * other.y }
    else if (type_info == .Int or type_info == .Float or type_info == .ComptimeInt or type_info == .ComptimeFloat)
        Vec2{ .x = self.x * other, .y = self.y * other }
    else
        @compileError("unsupported type");
}

pub fn div(self: Vec2, other: anytype) Vec2 {
    const type_of = @TypeOf(other);
    const type_info = @typeInfo(type_of);
    return if (type_of == Vec2)
        Vec2{ .x = self.x / other.x, .y = self.y / other.y }
    else if (type_info == .Int or type_info == .Float or type_info == .ComptimeInt or type_info == .ComptimeFloat)
        Vec2{ .x = self.x / other, .y = self.y / other }
    else
        @compileError("unsupported type");
}

pub fn length(self: Vec2) f32 {
    return @sqrt(self.x * self.x + self.y * self.y);
}
