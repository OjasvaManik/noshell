# noshell

An interactive, Unix-like shell built from scratch in Zig 0.16.0. 

`noshell` is designed with a focus on strict memory management and explicit dependency injection. It leverages Zig's latest I/O abstractions to create a backend-agnostic REPL environment with a custom terminal editor and a zero-fragmentation execution pipeline.

## Features

- **Raw-Mode Terminal Editor:** Custom POSIX `termios` line editor that intercepts keystrokes and ANSI escape sequences for direct terminal buffer manipulation.
- **Zero-Fragmentation AST:** Uses a recursive descent parser to build an Abstract Syntax Tree (AST), backed by a heap-based Arena Allocator to guarantee deterministic, O(1) memory cleanup per command cycle.
- **Backend-Agnostic I/O:** Built natively on Zig 0.16.0's `std.process.Init` and `std.Io`, enforcing strict dependency injection for all filesystem and process scheduler interactions.
- **Structured Built-ins:** Features native commands including a custom `ls` utility that outputs structured JSON and Nerd Font icons for machine-readable filesystem traversal.

## Building and Running

Ensure you have **Zig 0.16.0** installed.

```bash
zig build run
```

## Roadmap

### SQLite Integration
The immediate next step for `noshell` is embedding **SQLite** directly into the shell. This will serve as the backbone for:
- **Persistent Command History:** Replacing standard plaintext history files with a fully queryable database.
- **Settings & Configuration:** Storing all user preferences, environment maps, and shell states.
- **Customization:** Driving themes, aliases, and dynamic behaviors directly from the SQLite store.
