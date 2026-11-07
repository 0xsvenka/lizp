const std = @import("std");

pub const LispObject = union(enum) {
    nil,
    boolean: bool,
    integer: i64,
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
