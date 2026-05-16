const std = @import("std");
const SourceLocation = std.builtin.SourceLocation;

/// The one true cast operator
pub inline fn cast(Target: type, val: anytype) Target {
    const tti = @typeInfo(Target);

    return switch (tti) {
        .int => to_int(Target, val),
        .float => to_float(Target, val),
        .bool => to_bool(Target, val),
        .pointer => to_ptr(Target, val),
        .@"enum" => to_enum(Target, val),
        .optional => to_optional(Target, val),
        .@"struct", .@"union" => to_bits(Target, val),
        else => comperr(@src(), Target, val),
    };
}

/// to make life easier when using @bitcast
pub inline fn bitcast(Target: type, val: anytype) Target {
    return @bitCast(val);
}

pub inline fn to_int(Target: type, val: anytype) Target {
    return switch (@typeInfo(@TypeOf(val))) {
        .comptime_int, .int => @as(Target, @intCast(val)),
        .comptime_float, .float => @as(Target, @intFromFloat(val)),
        .@"struct", .@"union" => to_bits(Target, val),
        .@"enum" => @as(Target, @intCast(@intFromEnum(val))),
        .bool => @as(Target, @intFromBool(val)),
        .pointer => @as(Target, @intCast(@as(usize, @intFromPtr(val)))),
        .optional => if (val) |v| to_int(Target, v) else @as(Target, 0),
        else => comperr(@src(), Target, val),
    };
}

pub inline fn to_float(Target: type, val: anytype) Target {
    return switch (@typeInfo(@TypeOf(val))) {
        .comptime_int, .int => @as(Target, @floatFromInt(val)),
        .comptime_float, .float => @as(Target, @floatCast(val)),
        .@"struct", .@"union" => to_bits(Target, val),
        .bool => @as(Target, @floatFromInt(@intFromBool(val))),
        .@"enum" => @as(Target, @floatFromInt(@intFromEnum(val))),
        else => comperr(@src(), Target, val),
    };
}

pub inline fn to_bool(Target: type, val: anytype) Target {
    return switch (@typeInfo(@TypeOf(val))) {
        .comptime_int, .int => val != 0,
        .comptime_float, .float => val != 0.0,
        .pointer => @intFromPtr(val) != 0,
        .optional => if (val) |v| to_bool(Target, v) else false,
        .@"enum" => cast(bool, @intFromEnum(val)),
        else => comperr(@src(), Target, val),
    };
}

pub inline fn to_ptr(Target: type, val: anytype) Target {
    return switch (@typeInfo(@TypeOf(val))) {
        .comptime_int, .int => @as(Target, @ptrFromInt(val)),
        .pointer => @as(Target, @ptrCast(@alignCast(@constCast(val)))),
        .@"struct", .@"union" => to_bits(Target, val),
        else => comperr(@src(), Target, val),
    };
}

pub inline fn to_enum(Target: type, val: anytype) Target {
    return switch (@typeInfo(@TypeOf(val))) {
        .comptime_int, .int => @as(Target, @enumFromInt(val)),
        .@"enum" => @as(Target, @enumFromInt(@intFromEnum(val))),
        .@"struct", .@"union" => to_bits(Target, val),
        else => comperr(@src(), Target, val),
    };
}

pub inline fn to_bits(Target: type, val: anytype) Target {
    return @as(*Target, @ptrCast(@alignCast(@constCast(&val)))).*;
}

pub inline fn to_struct(Target: type, val: anytype) Target {
    return to_bits(Target, val);
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
    try TT.expectEqual(@as(f32, 1.0), cast(f32, ee.one));
}

test "bools" {
    const ee = enum { zero, one, two };
    try TT.expectEqual(false, cast(bool, 0));
    try TT.expectEqual(true, cast(bool, 1));
    try TT.expectEqual(false, cast(bool, ee.zero));
    try TT.expectEqual(true, cast(bool, ee.two));
    try TT.expectEqual(false, cast(bool, 0.0));
    try TT.expectEqual(true, cast(bool, 1.1));
    const zero_opt: ?i32 = 0;
    const one_opt: ?i32 = 1;
    const null_opt: ?i32 = null;
    try TT.expectEqual(false, cast(bool, zero_opt));
    try TT.expectEqual(true, cast(bool, one_opt));
    try TT.expectEqual(false, cast(bool, null_opt));
}
test "pointers" {
    var z: u32 = 123;
    try TT.expectEqual(true, cast(bool, &z));
    var x: ?*u32 = &z;
    try TT.expectEqual(true, cast(bool, x));
    x = null;
    try TT.expectEqual(false, cast(bool, x));
    try TT.expectEqual(@as(usize, 0), cast(usize, x));
    var c: [*c]u32 = &z;
    try TT.expectEqual(true, cast(bool, c));
    c = null;
    try TT.expectEqual(false, cast(bool, c));
}

test "structs" {
    const ss = extern struct { a: u32, b: u32 };
    const sa = ss{ .a = 123, .b = 321 };
    try TT.expectEqual(@as(u32, 123), cast(u32, sa));
}

test "struct to struct" {
    const A = extern struct { x: u16, y: u16 };
    const B = extern struct { lo: u16, hi: u16 };
    const a = A{ .x = 0xABCD, .y = 0x1234 };
    const b = cast(B, a);
    try TT.expectEqual(@as(u16, 0xABCD), b.lo);
    try TT.expectEqual(@as(u16, 0x1234), b.hi);
}

test "optional" {
    const f: ?f32 = 1.23;
    const f2: ??f32 = 2.34;
    try TT.expectEqual(@as(?u32, 1), cast(?u32, f));
    try TT.expectEqual(@as(??u32, 2), cast(??u32, f2));
}

test "float from bool" {
    try TT.expectEqual(@as(f32, 0.0), cast(f32, false));
    try TT.expectEqual(@as(f32, 1.0), cast(f32, true));
}

test "int from optional null" {
    const p: ?*u8 = null;
    try TT.expectEqual(@as(usize, 0), cast(usize, p));
}
