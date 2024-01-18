const std = @import("std");
const core = @import("mach-core");
const gpu = core.gpu;

pub const Uniforms = struct {
    translation: @Vector(2, f32),
    window_scale: @Vector(2, f32),
    scale: f32,
};

buffer: *gpu.Buffer,
uniforms: Uniforms,
last_position: ?@Vector(2, f32),

pub fn init() @This() {
    return .{
        .buffer = core.device.createBuffer(&.{
            .label = "sort uniform buffer",
            .usage = .{ .uniform = true, .copy_dst = true },
            .size = @sizeOf(Uniforms),
        }),
        .uniforms = .{
            .translation = .{ 0.0, 0.0 },
            .window_scale = .{ 1.0, 1.0 },
            .scale = 500.0,
        },
        .last_position = null,
    };
}

pub fn deinit(self: *@This()) void {
    self.buffer.release();
}

fn update(self: *@This()) void {
    core.queue.writeBuffer(self.buffer, 0, &[1]Uniforms{self.uniforms});
}

pub fn beginTranslation(self: *@This(), position: @Vector(2, f32)) void {
    self.last_position = position;
}

pub fn translate(self: *@This(), position: @Vector(2, f32)) void {
    if (self.last_position) |last_position| {
        const offset = last_position - position;
        self.uniforms.translation += offset / @as(@Vector(2, f32), @splat(self.uniforms.scale));
        self.last_position = position;
        self.update();
    }
}

pub fn endTranslation(self: *@This()) void {
    self.last_position = null;
}

pub fn updateWindowScale(self: *@This(), size: @Vector(2, f32)) void {
    self.uniforms.window_scale = size;
    self.update();
}

pub fn zoom(self: *@This(), factor: f32) void {
    self.uniforms.scale *= std.math.pow(f32, 2, factor);
    self.update();
}
