const std = @import("std");

pub fn execute(args: []const []const u8, alloc: std.mem.Allocator, env: *std.process.Environ.Map, stdout: *std.Io.Writer, io: std.Io) !void {
    var target: []const u8 = undefined;

    if (args.len == 0) {
        target = env.get("HOME") orelse {
            try stdout.print("noshell: cd: HOME not set\n", .{});
            return;
        };
    } else {
        target = args[0];
    }

    var final_target: []const u8 = target;
    if (std.mem.startsWith(u8, target, "~")) {
        if (env.get("HOME")) |home| {
            final_target = try std.fmt.allocPrint(alloc, "{s}{s}", .{ home, target[1..] });
        }
    }

    var new_dir = std.Io.Dir.cwd().openDir(io, final_target, .{}) catch |err| {
        if (err == error.FileNotFound) {
            try stdout.print("noshell: cd: {s}: No such file or directory\n", .{final_target});
        } else if (err == error.NotDir) {
            try stdout.print("noshell: cd: {s}: Not a directory\n", .{final_target});
        } else {
            try stdout.print("noshell: cd: {s}: {s}\n", .{ final_target, @errorName(err) });
        }
        return;
    };

    defer new_dir.close(io);

    std.process.setCurrentDir(io, new_dir) catch |err| {
        try stdout.print("noshell: cd: failed to set current dir: {s}\n", .{@errorName(err)});
    };
}
