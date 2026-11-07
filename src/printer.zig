const std = @import("std");
const testing = std.testing;

const Gardener = @import("Gardener.zig");
const lisp = @import("lisp.zig");
const LispObject = lisp.LispObject;

pub fn printObject(writer: *std.Io.Writer, obj: *const LispObject) !void {
    switch (obj.*) {
        .nil => try writer.writeAll("()"),
        .boolean => |value| try writer.writeAll(if (value) "#t" else "#f"),
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
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    var gardener = Gardener.init(arena.allocator());

    const n = try gardener.makeInteger(42);

    var buf: [16]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buf);
    try printObject(&writer, n);
    try testing.expectEqualStrings("42", writer.buffered());
}
