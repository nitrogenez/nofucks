const std = @import("std");
const log = std.log.scoped(.nf);

const FuckContext = @import("FuckContext.zig");

pub fn main() !void {
    // Stdout
    const stdout_fw = std.io.getStdOut().writer();
    var stdout_bw = std.io.bufferedWriter(stdout_fw);
    const stdout = stdout_bw.writer();

    // Stdin
    const stdin = std.io.getStdIn().reader();

    // Allocator
    var allocator = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = allocator.deinit();
    const gpa = allocator.allocator();

    // CLI args
    var args = try std.process.argsWithAllocator(gpa);
    defer args.deinit();
    _ = args.skip();

    const input_path = args.next() orelse {
        log.err("no input", .{});
        return;
    };

    // Make a brainfuck context
    var ctx = try FuckContext.parseFile(gpa, input_path);
    defer ctx.deinit();

    // Start execution
    log.info("created new context from {s}", .{input_path});
    log.info("context operations total: {d}", .{ctx.oplist.items.len});
    log.info("starting execution", .{});

    try stdout.writeByte('\n');
    var timer = std.time.Timer.start() catch unreachable;
    try ctx.exec(stdout, stdin);

    log.info("execution took {d}ms", .{std.time.ns_per_ms / timer.lap()});
    log.info("deinitializing context", .{});

    // Wrap it up and put it under a christmas tree
    try stdout.writeByte('\n');
    try stdout_bw.flush();
}
