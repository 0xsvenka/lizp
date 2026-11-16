const std = @import("std");
const testing = std.testing;
pub const Error = std.Io.Writer.Error;

const Gardener = @import("Gardener.zig");
const lisp = @import("lisp.zig");
const LispObject = lisp.LispObject;

pub fn printObject(writer: *std.Io.Writer, obj: *const LispObject) Error!void {
    switch (obj.*) {
        .nil => try writer.writeAll("()"),
        .t => try writer.writeAll("#t"),
        .f => try writer.writeAll("#f"),
        .integer => |value| try writer.print("{}", .{value}),
        .symbol => |value| try writer.print("{s}", .{value}),
        .pair => |pair| {
            try writer.writeByte('(');

            try printObject(writer, pair.car);
            var rest = pair.cdr;
            while (rest.* == .pair) {
                try writer.writeByte(' ');
                try printObject(writer, rest.pair.car);
                rest = rest.pair.cdr;
            }

            if (rest.* != .nil) {
                try writer.writeAll(" . ");
                try printObject(writer, rest);
            }

            try writer.writeByte(')');
        },
        .function => try writer.writeAll("<function>"),
    }
}

test "print nil" {
    const gpa = testing.allocator;
    var gardener = Gardener.init(gpa);
    defer gardener.deinit();
    var buf: [16]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buf);

    const nil = gardener.makeNil();
    try printObject(&writer, nil);
    try testing.expectEqualStrings("()", writer.buffered());
}

test "print true" {
    const gpa = testing.allocator;
    var gardener = Gardener.init(gpa);
    defer gardener.deinit();
    var buf: [16]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buf);

    const t = gardener.makeTrue();
    try printObject(&writer, t);
    try testing.expectEqualStrings("#t", writer.buffered());
}

test "print false" {
    const gpa = testing.allocator;
    var gardener = Gardener.init(gpa);
    defer gardener.deinit();
    var buf: [16]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buf);

    const f = gardener.makeFalse();
    try printObject(&writer, f);
    try testing.expectEqualStrings("#f", writer.buffered());
}

test "print an integer" {
    const gpa = testing.allocator;
    var gardener = Gardener.init(gpa);
    defer gardener.deinit();
    var buf: [16]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buf);

    const n = try gardener.makeInteger(42);
    try printObject(&writer, n);
    try testing.expectEqualStrings("42", writer.buffered());
}

test "print a symbol" {
    const gpa = testing.allocator;
    var gardener = Gardener.init(gpa);
    defer gardener.deinit();
    var buf: [16]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buf);

    const symbol = try gardener.makeSymbol("F0ObAr");
    try printObject(&writer, symbol);
    try testing.expectEqualStrings("F0ObAr", writer.buffered());
}

test "print a pair of two atoms" {
    const gpa = testing.allocator;
    var gardener = Gardener.init(gpa);
    defer gardener.deinit();
    var buf: [16]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buf);

    const pair = try gardener.makePair(
        try gardener.makeSymbol("flag"),
        gardener.makeTrue(),
    );
    try printObject(&writer, pair);
    try testing.expectEqualStrings("(flag . #t)", writer.buffered());
}

test "print a list" {
    const gpa = testing.allocator;
    var gardener = Gardener.init(gpa);
    defer gardener.deinit();
    var buf: [16]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buf);

    const list = try gardener.makePair(
        try gardener.makeSymbol("foo"),
        try gardener.makePair(
            try gardener.makeInteger(0),
            try gardener.makePair(
                try gardener.makeInteger(1),
                gardener.makeNil(),
            ),
        ),
    );
    try printObject(&writer, list);
    try testing.expectEqualStrings("(foo 0 1)", writer.buffered());
}

test "print an irregular list" {
    const gpa = testing.allocator;
    var gardener = Gardener.init(gpa);
    defer gardener.deinit();
    var buf: [16]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buf);

    const list = try gardener.makePair(
        try gardener.makeSymbol("foo"),
        try gardener.makePair(
            try gardener.makeInteger(0),
            try gardener.makePair(
                try gardener.makeInteger(1),
                try gardener.makeInteger(2),
            ),
        ),
    );
    try printObject(&writer, list);
    try testing.expectEqualStrings("(foo 0 1 . 2)", writer.buffered());
}

test "print a complicated form" {
    const gpa = testing.allocator;
    var gardener = Gardener.init(gpa);
    defer gardener.deinit();
    var buf: [32]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buf);

    const list = try gardener.makePair(
        try gardener.makeSymbol("lambda"),
        try gardener.makePair(
            try gardener.makePair(
                try gardener.makeSymbol("x"),
                try gardener.makeSymbol("xs"),
            ),
            try gardener.makePair(
                try gardener.makePair(
                    try gardener.makeSymbol("cons"),
                    try gardener.makePair(
                        try gardener.makeSymbol("x"),
                        try gardener.makePair(
                            try gardener.makeSymbol("xs"),
                            gardener.makeNil(),
                        ),
                    ),
                ),
                gardener.makeNil(),
            ),
        ),
    );
    try printObject(&writer, list);
    try testing.expectEqualStrings(
        "(lambda (x . xs) (cons x xs))",
        writer.buffered(),
    );
}
