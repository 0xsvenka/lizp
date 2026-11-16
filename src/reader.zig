const std = @import("std");
const testing = std.testing;

const Gardener = @import("Gardener.zig");
const lisp = @import("lisp.zig");
const LispObject = lisp.LispObject;

pub const ReaderError = error{
    UnexpectedChar,
    UnexpectedEOF,
};

pub const Error = ReaderError || Gardener.Error;

pub const Reader = struct {
    gardener: *Gardener,
    source: []const u8,
    pos: usize,

    pub fn init(gardener: *Gardener, source: []const u8) Reader {
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

    fn is_delimiter(ch: u8) bool {
        return std.ascii.isWhitespace(ch) or
            ch == '(' or ch == ')' or ch == '\'';
    }

    /// If the reader is already at EOF, returns `ReaderError.UnexpectedEOF`.
    fn nextObject(self: *Reader) Error!*LispObject {
        self.skipWhitespace();
        const ch = self.peek() orelse return ReaderError.UnexpectedEOF;
        switch (ch) {
            '(' => {
                return self.parseParen();
            },
            ')' => {
                return ReaderError.UnexpectedChar;
            },
            '\'' => {
                return self.parseQuote();
            },
            '.' => {
                const next_pos = self.pos + 1;
                if (next_pos >= self.source.len or
                    is_delimiter(self.source[next_pos]))
                {
                    // a single dot
                    return ReaderError.UnexpectedChar;
                } else {
                    // must be a symbol
                    return self.parseSymbol();
                }
            },
            else => {
                return self.parseSymbol();
            },
        }
    }

    /// Assumes the next character is `'`.
    fn parseQuote(self: *Reader) Error!*LispObject {
        self.advance();
        return self.gardener.makePair(
            try self.gardener.makeSymbol("quote"),
            try self.gardener.makePair(
                try self.nextObject(),
                self.gardener.makeNil(),
            ),
        );
    }

    test parseQuote {
        const gpa = testing.allocator;
        var gardener = Gardener.init(gpa);
        defer gardener.deinit();
        var reader = Reader.init(&gardener, "'a");

        const quote_a = try reader.parseQuote();
        try testing.expect(quote_a.* == .pair);

        try testing.expect(quote_a.pair.car.* == .symbol);
        try testing.expectEqualStrings("quote", quote_a.pair.car.symbol);

        try testing.expect(quote_a.pair.cdr.* == .pair);

        try testing.expect(quote_a.pair.cdr.pair.car.* == .symbol);
        try testing.expectEqualStrings("a", quote_a.pair.cdr.pair.car.symbol);

        try testing.expect(quote_a.pair.cdr.pair.cdr.* == .nil);
    }

    /// Assumes the next character starts a symbol.
    fn parseSymbol(self: *Reader) Error!*LispObject {
        const start = self.pos;
        self.advance();
        while (self.peek()) |ch| {
            if (is_delimiter(ch)) break;
            self.advance();
        }
        return self.gardener.makeSymbol(self.source[start..self.pos]);
    }

    /// Assumes the next character is `(`.
    fn parseParen(self: *Reader) Error!*LispObject {
        self.advance();
        var cars: std.ArrayList(*LispObject) = .empty;
        defer cars.deinit(self.gardener.allocator);

        while (true) {
            self.skipWhitespace();
            const ch = self.peek() orelse return ReaderError.UnexpectedEOF;
            switch (ch) {
                ')' => {
                    self.advance();
                    var i = cars.items.len;
                    var obj = self.gardener.makeNil();
                    while (i > 0) {
                        i -= 1;
                        obj = try self.gardener.makePair(cars.items[i], obj);
                    }
                    return obj;
                },
                '.' => {
                    const next_pos = self.pos + 1;
                    if (next_pos >= self.source.len) {
                        return ReaderError.UnexpectedEOF;
                    } else if (is_delimiter(self.source[next_pos])) {
                        // a single dot
                        self.advance();

                        if (cars.items.len == 0) return ReaderError.UnexpectedChar;

                        const cdr = try self.nextObject();

                        self.skipWhitespace();
                        const next_ch = self.peek() orelse return ReaderError.UnexpectedEOF;
                        if (next_ch != ')') return ReaderError.UnexpectedChar;

                        var i = cars.items.len;
                        var obj = cdr;
                        while (i > 0) {
                            i -= 1;
                            obj = try self.gardener.makePair(cars.items[i], obj);
                        }
                        return obj;
                    } else {
                        // must be a symbol
                        const next_obj = try self.parseSymbol();
                        try cars.append(self.gardener.allocator, next_obj);
                    }
                },
                else => {
                    const next_obj = try self.nextObject();
                    try cars.append(self.gardener.allocator, next_obj);
                },
            }
        }
    }
};

test {
    _ = Reader;
}
