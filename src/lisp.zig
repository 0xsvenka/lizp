const std = @import("std");

pub const LispObject = union(enum) {
    nil,
    boolean: bool,
    integer: i64,
    symbol: SymbolId,
    pair: Pair,
    function: Function,
};

pub const SymbolId = usize;
pub const SymbolName = []const u8;

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
    id: SymbolId,
    value: *LispObject,
};
