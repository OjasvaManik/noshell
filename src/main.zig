const std = @import("std");
const lexer = @import("lexer.zig");
const ast = @import("ast.zig");
const parser = @import("parser.zig");
const executor = @import("executor.zig");

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
        var parse = parser.Parser.init(&lex, arena);
        const tree = parse.parse() catch |err| {
            std.log.err("Parse Error: {}", .{err});
            continue;
        };

        executor.execute(tree, trimmed, arena, stdout, io, init.environ_map) catch |err| {
            std.log.err("Execution Engine Error: {}", .{err});
        };
    }
}

fn print_banner(stdout: *std.Io.Writer) !void {
    const art =
        \\  _____  ___      ______    ________  __    __    _______  ___      ___       
        \\ (\"   \|"  \    /    " \  /"        )/" |  | "\  /"     "||"  |    |"  |      
        \\ |.\\   \    |  // ____  \(:   \___/(:  (__)  :)(: ______)||  |    ||  |      
        \\ |: \.   \\  | /  /    ) :)\___  \   \/      \/  \/    |  |:  |    |:  |      
        \\ |.  \    \. |(: (____/ //  __/  \\  //  __  \\  // ___)_  \  |___  \  |___   
        \\ |    \    \ | \        /  /" \   :)(:  (  )  :)(:      "|( \_|:  \( \_|:  \  
        \\  \___|\____\)  \"_____/  (_______/  \__|  |__/  \_______) \_______)\_______) 
        \\
        \\
    ;

    try stdout.print("{s}", .{art});
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

    try stdout.print("\n{s}\n", .{display_path});
}

fn printTree(stdout: anytype, node: *const ast.AstNode, src: []const u8, depth: usize) !void {
    var i: usize = 0;
    while (i < depth) : (i += 1) try stdout.print("  ", .{});

    switch (node.*) {
        .command => |*c| {
            const prog = src[c.program.loc.start..c.program.loc.end];
            try stdout.print("Command: '{s}'\n", .{prog});

            for (c.args) |arg| {
                var j: usize = 0;
                while (j < depth + 1) : (j += 1) try stdout.print("  ", .{});
                const arg_text = src[arg.loc.start..arg.loc.end];
                try stdout.print("Arg: '{s}'\n", .{arg_text});
            }
        },
        .pipeline => |*p| {
            try stdout.print("Pipeline:\n", .{});
            try printTree(stdout, p.left, src, depth + 1);

            i = 0;
            while (i < depth) : (i += 1) try stdout.print("  ", .{});
            try stdout.print("  | (pipes to)\n", .{});

            try printTree(stdout, p.right, src, depth + 1);
        },
    }
}
