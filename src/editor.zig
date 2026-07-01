const std = @import("std");

pub const LineEditor = struct {
    alloc: std.mem.Allocator,
    orig_termios: std.posix.termios,

    pub fn init(alloc: std.mem.Allocator) LineEditor {
        return .{
            .alloc = alloc,
            .orig_termios = undefined,
        };
    }

    fn enableRawMode(self: *LineEditor) !void {
        self.orig_termios = try std.posix.tcgetattr(std.posix.STDIN_FILENO);
        var raw = self.orig_termios;

        raw.lflag.ECHO = false;
        raw.lflag.ICANON = false;
        raw.lflag.ISIG = false;

        try std.posix.tcsetattr(std.posix.STDIN_FILENO, .FLUSH, raw);
    }

    fn disableRawMode(self: *LineEditor) !void {
        try std.posix.tcsetattr(std.posix.STDIN_FILENO, .FLUSH, self.orig_termios);
    }

    const State = enum { Normal, Esc, EscBracket };

    pub fn readLine(self: *LineEditor, stdin: anytype, stdout: anytype) !?[]const u8 {
        try self.enableRawMode();
        defer self.disableRawMode() catch {};

        var buf: std.ArrayList(u8) = .empty;
        var state: State = .Normal;

        while (true) {
            const b = stdin.takeByte() catch |err| {
                if (err == error.EndOfStream) {
                    if (buf.items.len == 0) return null;
                    break;
                }
                return err;
            };

            switch (state) {
                .Normal => {
                    if (b == '\r' or b == '\n') {
                        try stdout.print("\r\n", .{});
                        break;
                    } else if (b == 3) {
                        try stdout.print("^C\r\n", .{});
                        return error.Interrupt;
                    } else if (b == 4) {
                        if (buf.items.len == 0) return null;
                    } else if (b == 127 or b == 8) {
                        if (buf.items.len > 0) {
                            _ = buf.pop();
                            try stdout.print("\x08 \x08", .{});
                        }
                    } else if (b == '\x1b') {
                        state = .Esc;
                    } else {
                        try buf.append(self.alloc, b);
                        try stdout.print("{c}", .{b});
                    }
                },
                .Esc => {
                    if (b == '[') state = .EscBracket else state = .Normal;
                },
                .EscBracket => {
                    if (b == 'A') {
                        try stdout.print("\r\x1b[K", .{});
                        const stub_cmd = "echo \"PULLED FROM DB\"";
                        buf.clearRetainingCapacity();
                        try buf.appendSlice(self.alloc, stub_cmd);
                        try stdout.print("noshell ==<> {s}", .{stub_cmd});
                    } else if (b == 'B') {}
                    state = .Normal;
                },
            }
        }

        return try buf.toOwnedSlice(self.alloc);
    }
};
