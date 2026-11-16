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
        .integer => |value| try writer.print("{d}", .{value}),
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

// TODO: other tests for printObject
test "printObject prints an integer" {
    const gpa = testing.allocator;
    var gardener = Gardener.init(gpa);
    defer gardener.deinit();

    const n = try gardener.makeInteger(42);
    var buf: [16]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buf);
    try printObject(&writer, n);
    try testing.expectEqualStrings("42", writer.buffered());
}
