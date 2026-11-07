const std = @import("std");

const Gardener = @import("Gardener.zig");
const lisp = @import("lisp.zig");
const LispObject = lisp.LispObject;

const ReaderError = error{
    UnexpectedChar,
    UnexpectedEOF,
};

const Reader = struct {
    gardener: *Gardener,
    source: []const u8,
    pos: usize,

    fn init(gardener: *Gardener, source: []const u8) Reader {
        return .{
            .gardener = gardener,
            .source = source,
            .pos = 0,
        };
    }

    fn peek(self: *const Reader) ?u8 {
        if (self.pos < self.source.len) {
            return self.source[self.pos];
        } else {
            return null;
        }
    }

    fn advance(self: *Reader) void {
        if (self.pos < self.source.len) {
            self.pos += 1;
        }
    }

    fn skipWhitespace(self: *Reader) void {
        while (self.peek()) |ch| {
            if (!std.ascii.isWhitespace(ch)) break;
            self.advance();
        }
    }

    fn nextObject(self: *Reader) !*LispObject {
        self.skipWhitespace();
        const ch = self.peek() orelse return ReaderError.UnexpectedEOF;
        return switch (ch) {
            '(' => self.parseParen(),
            ')' => ReaderError.UnexpectedChar,
            else => self.parseSymbol(),
        };
    }

    /// Assumes the next character starts a symbol.
    fn parseSymbol(self: *Reader) !*LispObject {
        const start = self.pos;
        self.advance();
        while (self.peek()) |ch| {
            if (std.ascii.isWhitespace(ch) or ch == '(' or ch == ')') break;
            self.advance();
        }
        return self.gardener.makeSymbol(self.source[start..self.pos]);
    }

    /// Assumes the next character is `(`.
    fn parseParen(self: *Reader) !*LispObject {
        self.advance();
        // TODO
    }
};
