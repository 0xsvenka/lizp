//! Owner of all Lisp objects; responsible for their planting (allocation)
//! and reaping (garbage collection).
//!
//! The instance of `Gardener` should be unique and long-lived.

const std = @import("std");
const testing = std.testing;
pub const Error = std.mem.Allocator.Error;

const lisp = @import("lisp.zig");
const LispObject = lisp.LispObject;

const Gardener = @This();

allocator: std.mem.Allocator,
/// Objects dynamically allocated by this `Gardener` instance.
/// Not including symbols, which are managed by `symbol_table`.
allocated_objs: std.AutoHashMap(*const LispObject, void),
symbol_table: SymbolTable,

nil: LispObject = .nil,
t: LispObject = .t,
f: LispObject = .f,

pub fn init(allocator: std.mem.Allocator) Gardener {
    return .{
        .allocator = allocator,
        .allocated_objs = std.AutoHashMap(*const LispObject, void).init(allocator),
        .symbol_table = SymbolTable.init(allocator),
    };
}

pub fn deinit(self: *Gardener) void {
    self.symbol_table.deinit();

    var iter = self.allocated_objs.iterator();
    while (iter.next()) |entry| {
        const obj = entry.key_ptr.*;
        self.allocator.destroy(obj);
    }

    self.allocated_objs.deinit();
}

fn allocateObject(self: *Gardener, obj: LispObject) Error!*LispObject {
    const ptr = try self.allocator.create(LispObject);
    errdefer self.allocator.destroy(ptr);

    try self.allocated_objs.put(ptr, {});

    ptr.* = obj;
    return ptr;
}

pub fn makeNil(self: *Gardener) *LispObject {
    return &self.nil;
}

test makeNil {
    const gpa = testing.allocator;
    var gardener = Gardener.init(gpa);
    defer gardener.deinit();

    const nil = gardener.makeNil();
    try testing.expect(nil.* == .nil);
}

pub fn makeTrue(self: *Gardener) *LispObject {
    return &self.t;
}

test makeTrue {
    const gpa = testing.allocator;
    var gardener = Gardener.init(gpa);
    defer gardener.deinit();

    const t = gardener.makeTrue();
    try testing.expect(t.* == .t);
}

pub fn makeFalse(self: *Gardener) *LispObject {
    return &self.f;
}

test makeFalse {
    const gpa = testing.allocator;
    var gardener = Gardener.init(gpa);
    defer gardener.deinit();

    const f = gardener.makeFalse();
    try testing.expect(f.* == .f);
}

pub fn makeInteger(self: *Gardener, value: i64) Error!*LispObject {
    return self.allocateObject(.{ .integer = value });
}

test makeInteger {
    const gpa = testing.allocator;
    var gardener = Gardener.init(gpa);
    defer gardener.deinit();

    const answer = try gardener.makeInteger(42);
    try testing.expect(answer.* == .integer);
    try testing.expectEqual(42, answer.integer);
}

pub fn makeSymbol(self: *Gardener, value: []const u8) Error!*LispObject {
    return self.symbol_table.intern(value);
}

test makeSymbol {
    const gpa = testing.allocator;
    var gardener = Gardener.init(gpa);
    defer gardener.deinit();

    const foo = try gardener.makeSymbol("FOO");
    try testing.expect(foo.* == .symbol);
    try testing.expectEqualStrings("FOO", foo.symbol);

    const bar = try gardener.makeSymbol("2147483647");
    try testing.expect(bar.* == .symbol);
    try testing.expectEqualStrings("2147483647", bar.symbol);

    const foo2 = try gardener.makeSymbol("FOO");
    try testing.expect(foo2.* == .symbol);
    try testing.expect(foo2 == foo);
}

pub fn makePair(
    self: *Gardener,
    car: *LispObject,
    cdr: *LispObject,
) Error!*LispObject {
    return self.allocateObject(.{
        .pair = .{ .car = car, .cdr = cdr },
    });
}

test makePair {
    const gpa = testing.allocator;
    var gardener = Gardener.init(gpa);
    defer gardener.deinit();

    const foo = try gardener.makeSymbol("FOO");
    const answer = try gardener.makeInteger(42);
    const pair = try gardener.makePair(foo, answer);
    try testing.expect(pair.* == .pair);

    const car = pair.pair.car;
    try testing.expect(car.* == .symbol);
    try testing.expect(car == foo);

    const cdr = pair.pair.cdr;
    try testing.expect(cdr.* == .integer);
    try testing.expect(cdr == answer);
}

pub fn makeFunction(
    self: *Gardener,
    params: *LispObject,
    body: *LispObject,
    env: *lisp.Env,
) Error!*LispObject {
    return self.allocateObject(.{
        .function = .{
            .params = params,
            .body = body,
            .env = env,
        },
    });
}

/// Owner of symbols.
const SymbolTable = struct {
    allocator: std.mem.Allocator,
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

    /// Returns the unique symbol of the given name,
    /// allocating the symbol if not already present.
    fn intern(self: *SymbolTable, name: []const u8) Error!*LispObject {
        if (self.symbols_by_name.get(name)) |symbol| {
            return symbol;
        }

        const name_owned = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(name_owned);

        const symbol = try self.allocator.create(LispObject);
        errdefer self.allocator.destroy(symbol);

        try self.symbols_by_name.put(name_owned, symbol);

        symbol.* = .{ .symbol = name_owned };
        return symbol;
    }
};
