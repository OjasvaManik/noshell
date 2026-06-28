const std = @import("std");
const lexer = @import("lexer.zig");
const ast = @import("ast.zig");

pub const Parser = struct {
    lex: *lexer.Lexer,
    alloc: std.mem.Allocator,
    current: lexer.Token,
    peek_token: lexer.Token,

    fn advance(self: *Parser) void {
        self.current = self.peek_token;
        self.peek_token = self.lex.next();
    }

    pub fn init(lex: *lexer.Lexer, alloc: std.mem.Allocator) Parser {
        var p = Parser{
            .lex = lex,
            .alloc = alloc,
            .current = undefined,
            .peek_token = undefined,
        };
        p.advance();
        p.advance();
        return p;
    }

    fn parse_command(self: *Parser) !*ast.AstNode {
        if (self.current.kind != .WORD and self.current.kind != .DQUOTE) {
            std.log.err("Syntax Error: Expected command name, got {s}", .{@tagName(self.current.kind)});
            return error.InvalidSyntax;
        }

        const program_token = self.current;
        const start_idx = program_token.loc.start;

        var args: std.ArrayList(lexer.Token) = .empty;
        errdefer args.deinit(self.alloc);

        self.advance();

        while (self.current.kind == .WORD or self.current.kind == .DQUOTE) {
            try args.append(self.alloc, self.current);
            self.advance();
        }

        const end_idx = if (args.items.len > 0)
            args.items[args.items.len - 1].loc.end
        else
            program_token.loc.end;

        const node = try self.alloc.create(ast.AstNode);
        node.* = .{ .command = .{ .program = program_token, .args = try args.toOwnedSlice(self.alloc), .loc = .{ .start = start_idx, .end = end_idx } } };
        return node;
    }

    fn parse_pipeline(self: *Parser) !*ast.AstNode {
        var left_node = try self.parse_command();
        if (self.current.kind == .PIPE) {
            self.advance();

            const right_node = try self.parse_pipeline();
            const pipe_node = try self.alloc.create(ast.AstNode);
            pipe_node.* = .{ .pipeline = .{ .left = left_node, .right = right_node, .loc = .{ .start = left_node.loc().start, .end = right_node.loc().end } } };

            return pipe_node;
        }
        return left_node;
    }

    pub fn parse(self: *Parser) !*ast.AstNode {
        if (self.current.kind == .EOF) {
            return error.EmptyInput;
        }
        return self.parse_pipeline();
    }
};
