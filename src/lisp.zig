const std = @import("std");

pub const LispObject = union(enum) {
    nil,
    t,
    f,
    integer: i64,
    /// Does not own its name string;
    /// both directly owned by `SymbolTable`.
    symbol: []const u8,
    pair: Pair,
    function: Function,
};

pub const Pair = struct {
    car: *LispObject,
    cdr: *LispObject,
};

pub const Function = struct {
    params: *LispObject,
    body: *LispObject,
    env: *Env,
};

pub const Env = struct {
    bindings: []Binding,
    parent: *Env,
};

pub const Binding = struct {
    id: *LispObject,
    value: *LispObject,
};

/// Compares object identities.
pub fn eq(a: *const LispObject, b: *const LispObject) bool {
    return a == b;
}

/// Compares object values.
///
/// It works by dispatching on `a`'s type. If the type is `integer` or `pair`,
/// then apply the corresponding comparison rule; otherwise, simply call `eq`.
pub fn equal(a: *const LispObject, b: *const LispObject) bool {
    switch (a.*) {
        .integer => {
            return b.* == .integer and a.integer == b.integer;
        },
        .pair => {
            return b.* == .pair and
                equal(a.pair.car, b.pair.car) and
                equal(a.pair.cdr, b.pair.cdr);
        },
        else => {
            return eq(a, b);
        },
    }
}
