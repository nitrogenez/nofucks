const std = @import("std");

pub const FuckToken = enum {
    inc,
    dec,
    movl,
    movr,
    out,
    in,
    loop_start,
    loop_end,

    pub fn fromByte(c: u8) ?FuckToken {
        return switch (c) {
            '+' => .inc,
            '-' => .dec,
            '<' => .movl,
            '>' => .movr,
            '.' => .out,
            ',' => .in,
            '[' => .loop_start,
            ']' => .loop_end,
            else => null,
        };
    }
};

pub const Error = error{
    LoopEnded,
    NoLoopEnd,
};

arena: std.heap.ArenaAllocator,
oplist: std.ArrayListUnmanaged(FuckToken) = undefined,
tape: std.ArrayListUnmanaged(u8) = undefined,
ptr: usize = 0,

pub fn deinit(self: *@This()) void {
    self.tape.deinit(self.arena.allocator());
    self.oplist.deinit(self.arena.allocator());
    self.arena.deinit();
    self.* = undefined;
}

pub fn parseFile(allocator: std.mem.Allocator, path: []const u8) !@This() {
    var fd = try std.fs.cwd().openFile(path, .{});
    const s = try fd.readToEndAlloc(allocator, 1024 * 1024);

    defer fd.close();
    defer allocator.free(s);

    return parseSlice(allocator, s);
}

pub fn parseSlice(allocator: std.mem.Allocator, s: []const u8) !@This() {
    var arena = std.heap.ArenaAllocator.init(allocator);
    const gpa = arena.allocator();
    var oplist = std.ArrayListUnmanaged(FuckToken){};
    var tape = std.ArrayListUnmanaged(u8){};

    try tape.append(gpa, 0);

    var fbs = std.io.fixedBufferStream(s);
    const r = fbs.reader();

    while (true) {
        const line = (try r.readUntilDelimiterOrEofAlloc(gpa, '\n', 2048)) orelse break;
        defer gpa.free(line);

        for (line) |c| {
            const op = FuckToken.fromByte(c) orelse continue;
            try oplist.append(gpa, op);
        }
    }

    return .{
        .arena = arena,
        .oplist = oplist,
        .tape = tape,
    };
}

pub fn exec(self: *@This(), stdout: anytype, stdin: anytype) anyerror!void {
    self.execTokenSlice(self.oplist.items, stdout, stdin) catch |err| switch (err) {
        Error.LoopEnded => {
            std.log.err("unexpected ']'", .{});
            return;
        },
        else => return err,
    };
}

pub fn execTokenSlice(self: *@This(), s: []const FuckToken, stdout: anytype, stdin: anytype) anyerror!void {
    for (s) |e| {
        switch (e) {
            .inc => self.tape.items[self.ptr] += 1,
            .dec => self.tape.items[self.ptr] -= 1,
            .movl => try self.movePtr(0),
            .movr => try self.movePtr(1),
            .out => try stdout.writeByte(self.tape.items[self.ptr]),
            .in => try self.readInput(stdin),
            else => return error.NotImplemented,
            // .loop_start => try self.execLoop(i, stdout, stdin),
            // .loop_end => return Error.LoopEnded,
        }
    }
}

fn readInput(self: *@This(), reader: anytype) anyerror!void {
    const in = try reader.readUntilDelimiterAlloc(self.arena.allocator(), '\n', 1024);
    defer self.arena.allocator().free(in);
    self.tape.items[self.ptr] = std.fmt.parseInt(u8, in, 10) catch |err| {
        std.log.err("bad input: {s}", .{@errorName(err)});
        return err;
    };
}

// fn execLoop(self: *@This(), loop_start: usize, stdout: anytype, stdin: anytype) anyerror!void {
//     const loop_end: usize = std.mem.indexOfScalarPos(
//         FuckToken,
//         self.oplist.items,
//         loop_start + 1,
//         .loop_end,
//     ) orelse {
//         std.log.err("expected closing ']'", .{});
//         return Error.NoLoopEnd;
//     };
//     const loop_oplist = self.oplist.items[loop_start .. loop_end + 1];

// std.log.debug("{}", .{loop_oplist[loop_oplist.len - 1]});

//     while (self.tape.items[self.ptr] != 0) {
//         self.execTokenSlice(loop_oplist, stdout, stdin) catch |err| switch (err) {
//             Error.LoopEnded => return,
//             else => return err,
//         };
//     }
// }

fn movePtr(self: *@This(), dir: u1) !void {
    switch (dir) {
        0 => {
            if (self.ptr == 0) {
                std.log.err("move_left: reached the start of the tape", .{});
                return;
            }
            self.ptr -= 1;
        },
        1 => {
            self.ptr += 1;

            if (self.ptr == self.tape.items.len)
                try self.tape.append(self.arena.allocator(), 0);
        },
    }
}
