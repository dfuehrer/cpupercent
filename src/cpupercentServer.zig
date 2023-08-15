const std = @import("std");
const percentgraph = @import("percentgraph");
//const percentgraph = @import("percentgraphServer.zig");

// TODO figure out how to get num cpus at compile time
const num_cpus = 16;
const num_percs = 1;
const server_t = percentgraph.PercentGraphServer(u64, (num_cpus + num_percs) * 2, num_cpus, num_percs);
var g_server: ?*server_t = null;

pub fn main() !void {
    try setupSignals();
    var buf: [100]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buf);
    //defer fba.deinit();
    const alloc = fba.allocator();
    var cachedir_al = try percentgraph.getCacheDir(alloc, "dwmblocks/cpupercent");
    defer cachedir_al.deinit();
    try cachedir_al.appendSlice("/test");
    var server = try server_t.init(cachedir_al.items);
    defer server.cleanup() catch unreachable;
    g_server = &server;
    try server.runServerFunc(runServer);
    g_server = null;
}

fn runServer(server: *server_t) void {
    const statfile = std.fs.openFileAbsolute("/proc/stat", .{ .mode = .read_only }) catch unreachable;
    defer statfile.close();
    var statreader = statfile.reader();
    const saved = server.getDatas();
    var tosave: [server_t.num_saved]server_t.stored_t = undefined;
    var percent: [server_t.num_print_perc]server_t.stored_t = undefined;
    var cpu_percents: [server_t.num_graph_perc]server_t.percent_t = undefined;

    var buf: [100]u8 = undefined;
    // user nice system idle iowait irq softirq steal guest guest_nice
    const active_inds = [_]bool{ true, true, true, false, false, true, true, true, true, true };
    const total_inds = [_]bool{ true, true, true, true, true, true, true, true, false, false };
    var cpu_line: usize = 0;
    while (cpu_line < server_t.num_graph_perc + server_t.num_print_perc) : (cpu_line += 1) {
        const line = statreader.readUntilDelimiter(&buf, '\n') catch unreachable;
        const cpu_col = "cpu";
        if (!std.mem.eql(u8, line[0..cpu_col.len], cpu_col)) {
            // TODO 0 out data
            break;
        }

        var active: server_t.stored_t = 0;
        var total: server_t.stored_t = 0;
        var colnum: usize = 0;
        var ind = cpu_col.len;
        while (colnum < total_inds.len) : (colnum += 1) {
            while (line[ind] == ' ') {
                ind += 1;
            }
            const spaceind = ind + (std.mem.indexOfScalar(u8, line[ind..], ' ') orelse break);
            const colstr = line[ind..spaceind];
            const usage = std.fmt.parseUnsigned(server_t.stored_t, colstr, 10) catch unreachable;
            ind = spaceind + 1;
            if (total_inds[colnum]) {
                total += usage;
                if (active_inds[colnum]) {
                    active += usage;
                }
            }
        }
        const perc = if (total == saved[cpu_line * 2 + 1])
            0
        else
            ((active - saved[cpu_line * 2]) * 100) / (total - saved[cpu_line * 2 + 1]);
        if (cpu_line >= server_t.num_print_perc) {
            cpu_percents[cpu_line - server_t.num_print_perc] = @truncate(server_t.percent_t, perc);
        } else {
            percent[cpu_line] = perc;
        }
        tosave[cpu_line * 2] = active;
        tosave[cpu_line * 2 + 1] = total;
    }
    //std.debug.print("percent overall: {}%, indiv percents: {any}\n", .{ percent[0], cpu_percents });

    server.setPercents(cpu_percents, &percent);
    server.saveDatas(&tosave);
}

fn sigHandler(signal: c_int) align(1) callconv(.C) void {
    // TODO figure out a way to do this other than a global var
    if (g_server) |server| {
        server.stopRunning();
        server.cleanup() catch unreachable;
    }
    const dfl = std.os.Sigaction{
        .handler = .{ .handler = std.os.SIG.DFL },
        .mask = std.os.empty_sigset,
        .flags = 0,
    };
    std.os.sigaction(@intCast(u6, signal), &dfl, null) catch unreachable;
}

fn setupSignals() !void {
    const act = std.os.Sigaction{
        .handler = .{ .handler = sigHandler },
        .mask = std.os.empty_sigset,
        .flags = 0,
    };
    try std.os.sigaction(std.os.SIG.HUP, &act, null);
    try std.os.sigaction(std.os.SIG.TERM, &act, null);
    try std.os.sigaction(std.os.SIG.INT, &act, null);
}
