const std = @import("std");

pub const TokenKind = enum {
    WORD,
    DQUOTE,
    PIPE,
    REDIRECT,
    BACKGROUND,
    SEMICOLON,
    AND,
    OR,
    NEWLINE,
    EOF,
};

pub const Token = struct {
    kind: TokenKind,
    loc: struct { start: usize, end: usize },
};

pub const Lexer = struct {
    src: []const u8,
    pos: usize,

    pub fn init(src: []const u8) Lexer {
        return .{ .src = src, .pos = 0 };
    }

    pub fn next(self: *Lexer) Token {
        self.skip_whitespace();
        if (self.pos > self.src.len) {
            return .{ .kind = .EOF, .loc = .{ .start = self.pos, .end = self.pos } };
        }

        const start = self.pos;
        const ch = self.src[self.pos];

        switch (ch) {
            '\n' => {
                self.pos += 1;
                return .{ .kind = .NEWLINE, .loc = .{ .start = start, .end = self.pos } };
            },
            '|' => {
                if (self.peek(1) == '|') {
                    self.pos += 2;
                    return .{ .kind = .OR, .loc = .{ .start = start, .end = self.pos } };
                } else {
                    self.pos += 1;
                    return .{ .kind = .PIPE, .loc = .{ .start = start, .end = self.pos } };
                }
            },
            '&' => {
                if (self.peek(1) == '&') {
                    self.pos += 2;
                    return .{ .kind = .AND, .loc = .{ .start = start, .end = self.pos } };
                } else {
                    self.pos += 1;
                    return .{ .kind = .BACKGROUND, .loc = .{ .start = start, .end = self.pos } };
                }
            },
            '>' => {
                if (self.peek(1) == '>') {
                    self.pos += 2;
                    return .{ .kind = .REDIRECT, .loc = .{ .start = start, .end = self.pos } };
                } else {
                    self.pos += 1;
                    return .{ .kind = .REDIRECT, .loc = .{ .start = start, .end = self.pos } };
                }
            },
            '<' => {
                self.pos += 1;
                return .{ .kind = .REDIRECT, .loc = .{ .start = start, .end = self.pos } };
            },
            ';' => {
                self.pos += 1;
                return .{ .kind = .SEMICOLON, .loc = .{ .start = start, .end = self.pos } };
            },
            '\'' => return self.read_single_quoted(),
            '"' => return self.read_double_quoted(),
            else => return self.read_word(),
        }
    }

    fn skip_whitespace(self: *Lexer) void {
        while (self.pos < self.src.len and (self.src[self.pos] == ' ' or self.src[self.pos] == '\t')) {
            self.pos += 1;
        }
    }

    fn peek(self: *Lexer, offset: usize) u8 {
        const idx = self.pos + offset;
        if (idx >= self.src.len) return 0;
        return self.src[idx];
    }

    fn read_single_quoted(self: *Lexer) Token {
        self.pos += 1;
        const start = self.pos;
        while (self.pos < self.src.len and self.src[self.pos] != '\'') {
            self.pos += 1;
        }
        if (self.pos < self.src.len) self.pos += 1;
        return .{ .kind = .WORD, .loc = .{ .start = start, .end = self.pos } };
    }

    fn read_double_quoted(self: *Lexer) Token {
        self.pos += 1;
        const start = self.pos;
        while (self.pos < self.src.len and self.src[self.pos] != '"') {
            self.pos += 1;
        }
        if (self.pos < self.src.len) self.pos += 1;
        return .{ .kind = .WORD, .loc = .{ .start = start, .end = self.pos } };
    }

    fn read_word(self: *Lexer) Token {
        const start = self.pos;
        while (self.pos < self.src.len) {
            const c = self.src[self.pos];
            switch (c) {
                ' ', '\t', '\n', '|', '&', ';', '>', '<', '\'', '"' => break,
                else => self.pos += 1,
            }
        }

        const text = self.src[start..self.pos];
        if (std.mem.eql(u8, text, "and")) {
            return .{ .kind = .AND, .loc = .{ .start = start, .end = self.pos } };
        }
        if (std.mem.eql(u8, text, "or")) {
            return .{ .kind = .OR, .loc = .{ .start = start, .end = self.pos } };
        }

        return .{ .kind = .WORD, .loc = .{ .start = start, .end = self.pos } };
    }
};
