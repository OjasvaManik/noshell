const std = @import("std");
const lexer = @import("lexer.zig");
const ast = @import("ast.zig");

pub const Parser = struct {
    lex: *lexer.Lexer,
    alloc: std.mem.Allocator, // This MUST be your temporary loop_arena!
    current: lexer.Token,
    peek_token: lexer.Token,

    pub fn init(lex: *lexer.Lexer, alloc: std.mem.Allocator) Parser {
        var p = Parser{
            .lex = lex,
            .alloc = alloc,
            .current = undefined,
            .peek_token = undefined,
        };
        // Prime the pump: load the first two tokens into our 1-token lookahead buffer
        p.advance();
        p.advance();
        return p;
    }

    // Pull the next token from the zero-allocation lexer
    fn advance(self: *Parser) void {
        self.current = self.peek_token;
        self.peek_token = self.lex.next();
    }

    // ---------------------------------------------------------
    // GRAMMAR RULES (Recursive Descent)
    // ---------------------------------------------------------

    // Entry Point: Parse a full line of input
    pub fn parse(self: *Parser) !*ast.AstNode {
        if (self.current.kind == .EOF) {
            return error.EmptyInput;
        }
        return self.parsePipeline();
    }

    // Rule: Pipeline ::= Command ( '|' Command )*
    fn parsePipeline(self: *Parser) !*ast.AstNode {
        // 1. Every pipeline must start with at least one command
        var left_node = try self.parseCommand();

        // 2. Look ahead: Do we see a PIPE token?
        if (self.current.kind == .PIPE) {
            self.advance(); // Eat the '|' token

            // 3. Recursively parse the right side of the pipe
            const right_node = try self.parsePipeline();

            // 4. Wrap them both in a Pipeline node
            const pipe_node = try self.alloc.create(ast.AstNode);
            pipe_node.* = .{ .pipeline = .{
                .left = left_node,
                .right = right_node,
                .loc = .{ .start = left_node.loc().start, .end = right_node.loc().end },
            } };
            return pipe_node;
        }

        // If there is no pipe, it's just a single command. Return it as-is.
        return left_node;
    }

    // Rule: Command ::= (WORD | DQUOTE) (WORD | DQUOTE)*
    // Rule: Command ::= (WORD | DQUOTE) (WORD | DQUOTE)*
    fn parseCommand(self: *Parser) !*ast.AstNode {
        if (self.current.kind != .WORD and self.current.kind != .DQUOTE) {
            std.log.err("Syntax Error: Expected command name, got {s}", .{@tagName(self.current.kind)});
            return error.InvalidSyntax;
        }

        const program_token = self.current;
        const start_idx = program_token.loc.start;

        // 1. ZIG 0.16 FIX: Initialize as an empty unmanaged list
        var args: std.ArrayList(lexer.Token) = .empty;

        // Ensure it cleans up on error. Pass the allocator to deinit!
        errdefer args.deinit(self.alloc);

        self.advance();

        while (self.current.kind == .WORD or self.current.kind == .DQUOTE) {
            // 2. ZIG 0.16 FIX: Pass the allocator into append
            try args.append(self.alloc, self.current);
            self.advance();
        }

        const end_idx = if (args.items.len > 0)
            args.items[args.items.len - 1].loc.end
        else
            program_token.loc.end;

        const node = try self.alloc.create(ast.AstNode);
        node.* = .{
            .command = .{
                .program = program_token,
                // 3. ZIG 0.16 FIX: Pass the allocator into toOwnedSlice
                .args = try args.toOwnedSlice(self.alloc),
                .loc = .{ .start = start_idx, .end = end_idx },
            },
        };

        return node;
    }
};
