const std = @import("std");
const log = std.log.scoped(.nofucks);

pub const Operation = enum {
    add,
    sub,
    movl,
    movr,
    out,
    in,
};

pub fn main() !void {
    const stdout_w = std.io.getStdOut().writer();
    var stdout_bw = std.io.bufferedWriter(stdout_w);
    const stdout = stdout_bw.writer();

    defer stdout_bw.flush() catch unreachable;

    var galloc = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa = galloc.allocator();

    defer _ = galloc.deinit();

    var args = try std.process.argsWithAllocator(gpa);
    defer args.deinit();

    _ = args.skip();

    const path = args.next() orelse {
        log.err("no input file provided", .{});
        return;
    };
    var in_fd = try std.fs.cwd().openFile(path, .{});
    defer in_fd.close();

    var ctx_ptr: usize = 0;
    var ctx_line: usize = 1;
    var ctx_column: usize = 1;
    var ctx_buf = std.ArrayList(u8).init(gpa);
    var op_buf = std.ArrayList(Operation).init(gpa);

    try ctx_buf.append(0);

    defer ctx_buf.deinit();
    defer op_buf.deinit();

    while (true) {
        const line = (try in_fd.reader().readUntilDelimiterOrEofAlloc(gpa, '\n', 2048)) orelse break;
        defer gpa.free(line);

        for (line) |c| {
            switch (c) {
                '+' => try op_buf.append(.add),
                '-' => try op_buf.append(.sub),
                '>' => try op_buf.append(.movr),
                '<' => try op_buf.append(.movl),
                '.' => try op_buf.append(.out),
                ',' => try op_buf.append(.in),
                else => {},
            }
            ctx_column += 1;
        }
        ctx_line += 1;
        ctx_column = 1;
    }

    for (op_buf.items) |op| {
        switch (op) {
            .add => {
                if (ctx_ptr > ctx_buf.items.len) {
                    log.err("index out of bounds: {d}", .{ctx_ptr});
                    return;
                }

                if (ctx_ptr == ctx_buf.items.len)
                    try ctx_buf.append(0);

                ctx_buf.items[ctx_ptr] += 1;
            },
            .sub => {
                if (ctx_ptr > ctx_buf.items.len) {
                    log.err("index out of bounds: {d}", .{ctx_ptr});
                    return;
                }

                if (ctx_ptr == ctx_buf.items.len)
                    try ctx_buf.append(0);

                ctx_buf.items[ctx_ptr] -= 1;
            },
            .movl => {
                if (ctx_ptr == 0) {
                    log.err("unable to move ptr left: reached the start of the tape", .{});
                    return;
                }
                ctx_ptr -= 1;
            },
            .movr => {
                ctx_ptr += 1;

                if (ctx_ptr == ctx_buf.items.len)
                    try ctx_buf.append(0);
            },
            .out => {
                try stdout.writeByte(ctx_buf.items[ctx_ptr]);
            },
            else => {
                log.err("operation {s} is not implemented", .{@tagName(op)});
                return;
            },
        }
    }
    try stdout.writeByte('\n');
}
