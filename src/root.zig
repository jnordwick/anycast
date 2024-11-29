const std = @import("std");
const SourceLocation = std.builtin.SourceLocation;

pub inline fn to_int(Target: type, val: anytype) Target {
    return switch (@typeInfo(@TypeOf(val))) {
        .ComptimeInt, .Int => @as(Target, @intCast(val)),
        .ComptimeFloat, .Float => @as(Target, @intFromFloat(val)),
        .Struct => to_struct(Target, val),
        .Enum => @as(Target, @intCast(@intFromEnum(val))),
        .Bool => @as(Target, @intFromBool(val)),
        .Pointer => @as(Target, @intCast(@as(usize, @intFromPtr(val)))),
        else => comperr(@src(), Target, val),
    };
}

pub inline fn to_float(Target: type, val: anytype) Target {
    return switch (@typeInfo(@TypeOf(val))) {
        .ComptimeInt, .Int => @as(Target, @floatFromInt(val)),
        .ComptimeFloat, .Float => @as(Target, @floatCast(val)),
        .Struct => to_struct(Target, val),
        .Bool => @as(Target, @floatFromInt(@intFromBool(val))),
        else => comperr(@src(), Target, val),
    };
}

pub inline fn to_bool(Target: type, val: anytype) Target {
    return switch (@typeInfo(@TypeOf(val))) {
        .ComptimeInt, .Int => val != 0,
        .ComptimeFloat, .Float => val != 0.0,
        .Pointer => val != null,
        .Enum => cast(bool, @intFromEnum(val)),
        else => comperr(@src(), Target, val),
    };
}

pub inline fn to_ptr(Target: type, val: anytype) Target {
    return switch (@typeInfo(@TypeOf(val))) {
        .ComptimeInt, .Int => @as(Target, @ptrFromInt(val)),
        .Pointer => @as(Target, @ptrCast(val)),
        .Struct => to_struct(Target, val),
        else => comperr(@src(), Target, val),
    };
}

pub inline fn to_enum(Target: type, val: anytype) Target {
    return switch (@typeInfo(@TypeOf(val))) {
        .ComptimeInt, .Int => @as(Target, @enumFromInt(val)),
        .Enum => @as(Target, @enumFromInt(@intFromEnum(val))),
        .Struct => to_struct(Target, val),
        else => comperr(@src(), Target, val),
    };
}

pub inline fn to_struct(Target: type, val: anytype) Target {
    const from_size = @sizeOf(@TypeOf(val));
    const to_size = @sizeOf(Target);
    if (to_size > from_size) {
        comperr(@src(), Target, val);
    }
    return @as(*Target, @constCast(@ptrCast(&val))).*;
}

inline fn comperr(src: SourceLocation, Target: type, val: anytype) noreturn {
    const loc = src.fn_name;
    @compileError(loc ++ ": invalid cast " ++ @typeName(Target) ++ " from " ++ @typeName(@TypeOf(val)));
}

pub inline fn cast(Target: type, val: anytype) Target {
    const tti = @typeInfo(Target);

    return switch (tti) {
        .Int => to_int(Target, val),
        .Float => to_float(Target, val),
        .Bool => to_bool(Target, val),
        .Pointer => to_ptr(Target, val),
        .Enum => to_enum(Target, val),
        else => @compileError("invalid target cast"),
    };
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
