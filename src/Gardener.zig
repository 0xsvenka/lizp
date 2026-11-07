//! Owner of all Lisp objects; responsible for their planting (allocation)
//! and reaping (garbage collection).
//!
//! The instance of `Gardener` should be unique and long-lived.

const std = @import("std");
const testing = std.testing;

const lisp = @import("lisp.zig");
const LispObject = lisp.LispObject;

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
    try testing.expectEqual(42, ultimate_answer.integer);
}

pub fn makeSymbol(self: *Gardener, value: []const u8) !*LispObject {
    return self.symbol_table.intern(value);
}

test makeSymbol {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    var gardener = Gardener.init(arena.allocator());

    const foo = try gardener.makeSymbol("FOO");
    try testing.expect(foo.* == .symbol);
    try testing.expectEqualStrings("FOO", foo.symbol);

    const bar = try gardener.makeSymbol("2147483647");
    try testing.expect(bar.* == .symbol);
    try testing.expectEqualStrings("2147483647", bar.symbol);

    const foo2 = try gardener.makeSymbol("FOO");
    try testing.expect(foo2.* == .symbol);
    try testing.expect(foo == foo2);
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

/// Direct owner of symbols.
const SymbolTable = struct {
    allocator: std.mem.Allocator,
    /// Owns the symbols as well as their name strings.
    symbols_by_name: std.StringHashMap(*LispObject),

    fn init(allocator: std.mem.Allocator) SymbolTable {
        return .{
            .allocator = allocator,
            .symbols_by_name = std.StringHashMap(*LispObject).init(allocator),
        };
    }

    fn deinit(self: *SymbolTable) void {
        var iter = self.symbols_by_name.iterator();
        while (iter.next()) |entry| {
            const name = entry.key_ptr.*;
            const symbol = entry.value_ptr.*;
            self.allocator.destroy(symbol);
            self.allocator.free(name);
        }

        self.symbols_by_name.deinit();
    }

    /// Returns the unique symbol of the given name.
    fn intern(self: *SymbolTable, name: []const u8) !*LispObject {
        if (self.symbols_by_name.get(name)) |symbol| {
            return symbol;
        }

        const name_owned = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(name_owned);

        const symbol = try self.allocator.create(LispObject);
        errdefer self.allocator.destroy(symbol);

        symbol.* = .{ .symbol = name_owned };
        try self.symbols_by_name.put(name_owned, symbol);
        return symbol;
    }
};
