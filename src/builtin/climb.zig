const std = @import("std");

pub fn execute(args: []const []const u8, stdout: *std.Io.Writer, io: std.Io) !void {
    var levels: usize = 1;
    if (args.len > 0) {
        levels = std.fmt.parseInt(usize, args[0], 10) catch {
            try stdout.print("noshell: climb: numeric argument required, got '{s}'\n", .{args[0]});
            return;
        };
    }

    var i: usize = 0;
    while (i < levels) : (i += 1) {
        var parent_dir = std.Io.Dir.cwd().openDir(io, "..", .{}) catch |err| {
            try stdout.print("noshell: climb: failed to open parent directory at level {d}: {s}\n", .{ i + 1, @errorName(err) });
            return;
        };

        std.process.setCurrentDir(io, parent_dir) catch |err| {
            parent_dir.close(io);
            try stdout.print("noshell: climb: failed to set parent directory at level {d}: {s}\n", .{ i + 1, @errorName(err) });
            return;
        };

        parent_dir.close(io);
    }
}
