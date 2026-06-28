const std = @import("std");
const lexer = @import("lexer.zig");

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    const stdout_file = std.Io.File.stdout();
    var stdout_buf: [4096]u8 = undefined;
    var stdout_impl = stdout_file.writer(io, &stdout_buf);
    const stdout = &stdout_impl.interface;

    const stdin_file = std.Io.File.stdin();
    var stdin_buf: [4096]u8 = undefined;
    var stdin_impl = stdin_file.reader(io, &stdin_buf);
    const stdin = &stdin_impl.interface;

    try print_banner(stdout);
    try stdout.flush();

    while (true) {
        var alloc = std.heap.ArenaAllocator.init(init.gpa);
        defer alloc.deinit();

        const arena = alloc.allocator();

        try print_prompt(io, stdout, arena, init.environ_map);
        try stdout.flush();

        const mayble_line = stdin.takeDelimiter('\n') catch |err| {
            std.log.err("Read Error: {}", .{err});
            break;
        };
        const line = mayble_line orelse break;
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (trimmed.len == 0) continue;

        var lex = lexer.Lexer.init(trimmed);

        try stdout.print("You typed: {s}\n", .{trimmed});
        try stdout.print("\n", .{});
        try stdout.flush();
    }
}

fn print_banner(stdout: *std.Io.Writer) !void {
    try stdout.print("\n", .{});
    try stdout.print("<><><><><><><><><><>\n", .{});
    try stdout.print(" Welcome to noshell\n", .{});
    try stdout.print("<><><><><><><><><><>\n", .{});
    try stdout.print("\n", .{});
}

fn print_prompt(io: std.Io, stdout: *std.Io.Writer, alloc: std.mem.Allocator, env: *std.process.Environ.Map) !void {
    var cwd_buf: [std.Io.Dir.max_path_bytes]u8 = undefined;
    const cwd: []const u8 = if (std.process.currentPath(io, &cwd_buf)) |len|
        cwd_buf[0..len]
    else |_|
        "?";

    var display_path: []const u8 = cwd;
    var home_replaced: ?[]u8 = null;

    if (env.get("HOME")) |home| {
        if (std.mem.startsWith(u8, cwd, home)) {
            const rest = cwd[home.len..];
            home_replaced = try std.fmt.allocPrint(alloc, "~{s}", .{rest});
            display_path = home_replaced.?;
        }
    }

    try stdout.print("{s} ==<>\n", .{display_path});
}
