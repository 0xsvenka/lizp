const std = @import("std");

const lisp = @import("lisp.zig");
const LispObject = lisp.LispObject;

fn car(obj: *const LispObject) *LispObject {
    switch (obj.*) {
        .pair => |pair| {
            return pair.car;
        },
        else => unreachable, // TODO: throw exception
    }
}

fn setCar(obj: *LispObject, new_car: *LispObject) void {
    switch (obj.*) {
        .pair => |*pair| {
            pair.car = new_car;
        },
        else => unreachable, // TODO: throw exception
    }
}
