const std = @import("std");
const lexer = @import("lexer.zig");

pub const Loc = struct { start: usize, end: usize };

pub const AstNode = union(enum) {
    command: Command,
    pipeline: Pipeline,

    pub fn loc(self: *const AstNode) Loc {
        return switch (self.*) {
            .command => |*c| c.loc,
            .pipeline => |*p| p.loc,
        };
    }
};

pub const Command = struct { program: lexer.Token, args: []const lexer.Token, loc: Loc };

pub const Pipeline = struct { left: *AstNode, right: *AstNode, loc: Loc };
