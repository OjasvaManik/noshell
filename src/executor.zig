const std = @import("std");
const ast = @import("ast.zig");

const cd = @import("builtin/cd.zig");
const climb = @import("builtin/climb.zig");
const ls = @import("builtin/ls.zig");

pub fn execute(node: *const ast.AstNode, src: []const u8, alloc: std.mem.Allocator, stdout: *std.Io.Writer, io: std.Io, env: *std.process.Environ.Map) !void {
    switch (node.*) {
        .command => |*c| try exec_command(c, src, alloc, stdout, io, env),
        .pipeline => |*p| {
            std.log.info("PIPLINES SOON!", .{});
            _ = p;
        },
    }
}

fn exec_command(cmd: *const ast.Command, src: []const u8, alloc: std.mem.Allocator, stdout: *std.Io.Writer, io: std.Io, env: *std.process.Environ.Map) !void {
    const prog_name = src[cmd.program.loc.start..cmd.program.loc.end];
    const argv = try alloc.alloc([]const u8, cmd.args.len + 1);
    argv[0] = prog_name;

    for (cmd.args, 0..) |arg_tok, i| {
        argv[i + 1] = src[arg_tok.loc.start..arg_tok.loc.end];
    }

    if (std.mem.eql(u8, prog_name, "cd")) {
        try cd.execute(argv[1..], alloc, env, stdout, io);
        return;
    }
    if (std.mem.eql(u8, prog_name, "climb")) {
        try climb.execute(argv[1..], stdout, io);
        return;
    }
    if (std.mem.eql(u8, prog_name, "ls")) {
        try ls.execute(argv[1..], alloc, stdout, io);
        return;
    }
    if (std.mem.eql(u8, prog_name, "exit")) {
        std.process.exit(0);
    }

    var child = std.process.spawn(io, .{ .argv = argv }) catch |err| {
        if (err == error.FileNotFound) {
            try stdout.print("noshell: command not found: {s}\n", .{prog_name});
        } else {
            try stdout.print("noshell: falied to execute '{s}': {}", .{ prog_name, err });
        }
        return;
    };

    _ = try child.wait(io);
}
