const std = @import("std");
const SourceLocation = std.builtin.SourceLocation;

pub inline fn to_int(Target: type, val: anytype) Target {
    return switch (@typeInfo(@TypeOf(val))) {
        .comptime_int, .int => @as(Target, @intCast(val)),
        .comptime_float, .float => @as(Target, @intFromFloat(val)),
        .@"struct" => to_struct(Target, val),
        .@"enum" => @as(Target, @intCast(@intFromEnum(val))),
        .bool => @as(Target, @intFromBool(val)),
        .pointer => @as(Target, @intCast(@as(usize, @intFromPtr(val)))),
        else => comperr(@src(), Target, val),
    };
}

pub inline fn to_float(Target: type, val: anytype) Target {
    return switch (@typeInfo(@TypeOf(val))) {
        .comptime_int, .int => @as(Target, @floatFromInt(val)),
        .comptime_float, .float => @as(Target, @floatCast(val)),
        .@"struct" => to_struct(Target, val),
        .bool => @as(Target, @floatFromInt(@intFromBool(val))),
        else => comperr(@src(), Target, val),
    };
}

pub inline fn to_bool(Target: type, val: anytype) Target {
    return switch (@typeInfo(@TypeOf(val))) {
        .comptime_int, .int => val != 0,
        .comptime_float, .float => val != 0.0,
        .pointer => val != null,
        .@"enum" => cast(bool, @intFromEnum(val)),
        else => comperr(@src(), Target, val),
    };
}

pub inline fn to_ptr(Target: type, val: anytype) Target {
    return switch (@typeInfo(@TypeOf(val))) {
        .comptime_int, .int => @as(Target, @ptrFromInt(val)),
        .pointer => @as(Target, @ptrCast(@alignCast(@constCast(val)))),
        .@"struct" => to_struct(Target, val),
        else => comperr(@src(), Target, val),
    };
}

pub inline fn to_enum(Target: type, val: anytype) Target {
    return switch (@typeInfo(@TypeOf(val))) {
        .comptime_int, .int => @as(Target, @enumFromInt(val)),
        .@"enum" => @as(Target, @enumFromInt(@intFromEnum(val))),
        .@"struct" => to_struct(Target, val),
        else => comperr(@src(), Target, val),
    };
}

pub inline fn to_struct(Target: type, val: anytype) Target {
    const from_size = @sizeOf(@TypeOf(val));
    const to_size = @sizeOf(Target);
    if (to_size > from_size) {
        comperr(@src(), Target, val);
    }
    return @as(*Target, @ptrCast(@alignCast(@constCast(&val)))).*;
}

pub inline fn to_optional(Target: type, val: anytype) Target {
    return switch (@typeInfo(@TypeOf(val))) {
        .optional => if (val) |v| cast(@typeInfo(Target).optional.child, v) else null,
        else => comperr(@src(), Target, val),
    };
}

inline fn comperr(src: SourceLocation, Target: type, val: anytype) noreturn {
    const loc = src.fn_name;
    @compileError(loc ++ ": invalid cast " ++ @typeName(Target) ++ " from " ++ @typeName(@TypeOf(val)));
}

pub inline fn cast(Target: type, val: anytype) Target {
    const tti = @typeInfo(Target);

    return switch (tti) {
        .int => to_int(Target, val),
        .float => to_float(Target, val),
        .bool => to_bool(Target, val),
        .pointer => to_ptr(Target, val),
        .@"enum" => to_enum(Target, val),
        .optional => to_optional(Target, val),
        else => @compileError("invalid target cast"),
    };
}

pub inline fn bitcast(Target: type, val: anytype) Target {
    return @bitCast(val);
}

// ====================================

const TT = std.testing;

test "numbers" {
    try TT.expectEqual(@as(u8, 3), cast(u8, 3.45));
    try TT.expectEqual(@as(f32, 3.0), cast(f32, 3));
}

test "enums" {
    const ee = enum { zero, one, two };
    const ff = enum { ff, tt };
    try TT.expectEqual(@as(usize, 1), cast(usize, ee.one));
    try TT.expectEqual(@as(usize, 1), cast(usize, ee.one));
    try TT.expectEqual(ff.tt, cast(ff, ee.one));
}

test "bools" {
    const ee = enum { zero, one, two };
    try TT.expectEqual(false, cast(bool, 0));
    try TT.expectEqual(true, cast(bool, 1));
    try TT.expectEqual(false, cast(bool, ee.zero));
    try TT.expectEqual(true, cast(bool, ee.two));
    try TT.expectEqual(false, cast(bool, 0.0));
    try TT.expectEqual(true, cast(bool, 1.1));
}

test "pointers" {
    var z: u32 = 123;
    var x: [*c]u32 = &z;
    try TT.expectEqual(true, cast(bool, x));
    x = null;
    try TT.expectEqual(false, cast(bool, x));
}

test "structs" {
    const ss = extern struct { a: u32, b: u32 };
    const sa = ss{ .a = 123, .b = 321 };
    try TT.expectEqual(@as(u32, 123), cast(u32, sa));
}

test "optional" {
    const f: ?f32 = 1.23;
    const f2: ??f32 = 2.34;
    try TT.expectEqual(@as(?u32, 1), cast(?u32, f));
    try TT.expectEqual(@as(??u32, 2), cast(??u32, f2));
}
