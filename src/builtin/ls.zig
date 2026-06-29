const std = @import("std");

const FileEntry = struct {
    name: []const u8,
    kind: []const u8,
    icon: []const u8,
    size: u64,
    modified_ts: i64,
    children: ?[]FileEntry = null,
};

pub fn execute(args: []const []const u8, alloc: std.mem.Allocator, stdout: *std.Io.Writer, io: std.Io) !void {
    var show_all = false;
    var tree_mode = false;
    var target_path: []const u8 = ".";

    for (args) |arg| {
        if (std.mem.eql(u8, arg, "-a")) {
            show_all = true;
        } else if (std.mem.eql(u8, arg, "-t")) {
            tree_mode = true;
        } else if (!std.mem.startsWith(u8, arg, "-")) {
            target_path = arg;
        }
    }

    var base_dir = std.Io.Dir.cwd().openDir(io, target_path, .{ .iterate = true }) catch |err| {
        try stdout.print("{{\"error\": \"noshell: ls: {s}: {s}\"}}\n", .{ target_path, @errorName(err) });
        return;
    };
    defer base_dir.close(io);

    const entries = try build_directory_tree(alloc, io, &base_dir, show_all, tree_mode, 0);
    const is_tty = try std.Io.File.stdout().isTty(io);

    if (is_tty) {
        var strfy: std.json.Stringify = .{
            .writer = stdout,
            .options = .{
                .emit_null_optional_fields = false,
                .whitespace = .indent_2,
            },
        };
        try strfy.write(entries);
    } else {
        var strfy: std.json.Stringify = .{
            .writer = stdout,
            .options = .{
                .emit_null_optional_fields = false,
            },
        };
        try strfy.write(entries);
    }

    try stdout.print("\n", .{});
}

fn build_directory_tree(alloc: std.mem.Allocator, io: std.Io, dir: *std.Io.Dir, show_all: bool, tree_mode: bool, depth: usize) ![]FileEntry {
    if (depth > 5) return &[_]FileEntry{};

    var list: std.ArrayList(FileEntry) = .empty;
    errdefer list.deinit(alloc);

    var it = dir.iterate();

    while (try it.next(io)) |entry| {
        if (!show_all and std.mem.startsWith(u8, entry.name, ".")) continue;

        const stat = dir.statFile(io, entry.name, .{}) catch null;
        const size = if (stat) |s| s.size else 0;
        const mtime = if (stat) |s| s.mtime.toSeconds() else 0;

        var children: ?[]FileEntry = null;
        if (tree_mode and entry.kind == .directory) {
            if (dir.openDir(io, entry.name, .{ .iterate = true })) |*sub_dir| {
                children = try build_directory_tree(alloc, io, @constCast(sub_dir), show_all, tree_mode, depth + 1);
                sub_dir.close(io);
            } else |_| {}
        }

        try list.append(alloc, .{
            .name = try alloc.dupe(u8, entry.name),
            .kind = @tagName(entry.kind),
            .icon = get_icon(entry.kind, entry.name),
            .size = size,
            .modified_ts = mtime,
            .children = children,
        });
    }
    return list.toOwnedSlice(alloc);
}

fn get_icon(kind: anytype, name: []const u8) []const u8 {
    if (kind == .directory) {
        return "\u{f07b} ";
    }
    if (kind == .sym_link) {
        return "\u{f0c1} ";
    }

    if (std.mem.endsWith(u8, name, ".zig")) {
        return "\u{e6a8} ";
    }
    if (std.mem.endsWith(u8, name, ".json")) {
        return "\u{e60b} ";
    }
    if (std.mem.endsWith(u8, name, ".md")) {
        return "\u{f033a}";
    }
    if (std.mem.endsWith(u8, name, ".txt")) {
        return "\u{f0f6} ";
    }
    if (std.mem.endsWith(u8, name, ".png") or std.mem.endsWith(u8, name, ".jpg") or std.mem.endsWith(u8, name, ".jpeg")) {
        return "\u{f1c5} ";
    }
    if (std.mem.endsWith(u8, name, ".lock") or std.mem.endsWith(u8, name, ".zon")) {
        return "\u{f023} ";
    }
    if (std.mem.startsWith(u8, name, "git") or std.mem.endsWith(u8, name, ".gitignore")) {
        return "\u{e702} ";
    }

    return "\u{f114} ";
}
