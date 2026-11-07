//! Owner of all Lisp objects; responsible for their planting (allocation)
//! and reaping (garbage collection).
//!
//! The instance of `Gardener` should be unique and long-lived.

const std = @import("std");
const testing = std.testing;

const lisp = @import("lisp.zig");
const LispObject = lisp.LispObject;
const SymbolId = lisp.SymbolId;
const SymbolName = lisp.SymbolName;

const Gardener = @This();

allocator: std.mem.Allocator,
symbol_table: SymbolTable,

nil: LispObject = .nil,
true_value: LispObject = .{ .boolean = true },
false_value: LispObject = .{ .boolean = false },

pub fn init(allocator: std.mem.Allocator) Gardener {
    return .{
        .allocator = allocator,
        .symbol_table = SymbolTable.init(allocator),
    };
}

pub fn deinit(self: *Gardener) void {
    self.symbol_table.deinit();
}

pub fn printObject(
    self: *const Gardener,
    writer: *std.Io.Writer,
    obj: *const LispObject,
) !void {
    switch (obj.*) {
        .nil => try writer.writeAll("()"),
        .boolean => |value| try writer.writeAll(if (value) "#t" else "#f"),
        .integer => |value| try writer.print("{d}", .{value}),
        .symbol => |value| try writer.writeAll(self.symbol_table.getName(value)),
        .pair => |pair| {
            try writer.writeByte('(');

            try self.printObject(writer, pair.car);
            var rest = pair.cdr;
            while (rest.* == .pair) {
                try writer.writeByte(' ');
                try self.printObject(writer, rest.pair.car);
                rest = rest.pair.cdr;
            }

            if (rest.* != .nil) {
                try writer.writeAll(" . ");
                try self.printObject(writer, rest);
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
    try gardener.printObject(&writer, n);
    try testing.expectEqualStrings("42", writer.buffered());
}

fn allocateObject(self: *const Gardener, obj: LispObject) !*LispObject {
    const ptr = try self.allocator.create(LispObject);
    ptr.* = obj;
    return ptr;
}

pub fn makeNil(self: *Gardener) *LispObject {
    return &self.nil;
}

test makeNil {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    var gardener = Gardener.init(arena.allocator());

    const nil = gardener.makeNil();
    try testing.expect(nil.* == .nil);
}

pub fn makeTrue(self: *Gardener) *LispObject {
    return &self.true_value;
}

test makeTrue {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    var gardener = Gardener.init(arena.allocator());

    const t = gardener.makeTrue();
    try testing.expect(t.* == .boolean);
    try testing.expectEqual(true, t.boolean);
}

pub fn makeFalse(self: *Gardener) *LispObject {
    return &self.false_value;
}

test makeFalse {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    var gardener = Gardener.init(arena.allocator());

    const f = gardener.makeFalse();
    try testing.expect(f.* == .boolean);
    try testing.expectEqual(false, f.boolean);
}

pub fn makeInteger(self: *const Gardener, value: i64) !*LispObject {
    return self.allocateObject(.{ .integer = value });
}

test makeInteger {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    var gardener = Gardener.init(arena.allocator());

    const ultimate_answer = try gardener.makeInteger(42);
    try testing.expect(ultimate_answer.* == .integer);
    try testing.expectEqual(@as(i64, 42), ultimate_answer.integer);
}

pub fn makeSymbol(self: *Gardener, value: SymbolName) !*LispObject {
    const symbol_id = try self.symbol_table.intern(value);
    return self.allocateObject(.{ .symbol = symbol_id });
}

test makeSymbol {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    var gardener = Gardener.init(arena.allocator());

    const foo = try gardener.makeSymbol("FOO");
    try testing.expect(foo.* == .symbol);
    try testing.expectEqual(0, foo.symbol);
    try testing.expectEqualStrings(
        gardener.symbol_table.names.items[foo.symbol],
        "FOO",
    );

    const lambda = try gardener.makeSymbol("lambda");
    try testing.expect(lambda.* == .symbol);
    try testing.expectEqual(1, lambda.symbol);
    try testing.expectEqualStrings(
        gardener.symbol_table.names.items[lambda.symbol],
        "lambda",
    );

    const foo2 = try gardener.makeSymbol("FOO");
    try testing.expect(foo2.* == .symbol);
    try testing.expectEqual(0, foo2.symbol);
    try testing.expectEqualStrings(
        gardener.symbol_table.names.items[foo2.symbol],
        "FOO",
    );
}

pub fn makePair(
    self: *const Gardener,
    car: *LispObject,
    cdr: *LispObject,
) !*LispObject {
    return self.allocateObject(.{
        .pair = .{ .car = car, .cdr = cdr },
    });
}

pub fn makeFunction(
    self: *const Gardener,
    params: *LispObject,
    body: *LispObject,
    env: *lisp.Env,
) !*LispObject {
    return self.allocateObject(.{
        .function = .{
            .params = params,
            .body = body,
            .env = env,
        },
    });
}

const SymbolTable = struct {
    allocator: std.mem.Allocator,
    /// Owns the symbol name strings.
    names: std.ArrayList(SymbolName),
    id_by_name: std.StringHashMap(SymbolId),

    fn init(allocator: std.mem.Allocator) SymbolTable {
        return .{
            .allocator = allocator,
            .names = .empty,
            .id_by_name = std.StringHashMap(SymbolId).init(allocator),
        };
    }

    fn deinit(self: *SymbolTable) void {
        self.id_by_name.deinit();

        for (self.names.items) |name| {
            self.allocator.free(name);
        }
        self.names.deinit(self.allocator);
    }

    fn intern(self: *SymbolTable, name: SymbolName) !SymbolId {
        if (self.id_by_name.get(name)) |id| {
            return id;
        }

        const id = self.names.items.len;

        const owned_name = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(owned_name);

        try self.names.append(self.allocator, owned_name);
        errdefer _ = self.names.pop();

        try self.id_by_name.put(owned_name, id);

        return id;
    }

    /// Assumes `id` is valid, i.e., `id < self.names.items.len`.
    fn getName(self: *const SymbolTable, id: SymbolId) SymbolName {
        return self.names.items[id];
    }
};
