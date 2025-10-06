const std = @import("std");
const percentgraph = @import("percentgraph");
//const percentgraph = @import("percentgraphServer.zig");
const params = @import("compile_params");

const num_percs = 1;
const server_t = percentgraph.PercentGraphServer(u64, (params.num_cpus + num_percs) * 2, params.num_cpus, num_percs);
var g_server: ?*server_t = null;

pub fn main() !void {
    setupSignals();
    var buf: [128]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buf);
    //defer fba.deinit();
    const alloc = fba.allocator();
    var cachedir_al = try percentgraph.getCacheDir(alloc, "dwmblocks/cpupercent");
    defer cachedir_al.deinit(alloc);
    try cachedir_al.appendSlice(alloc, "/cpupercent");
    var server = try server_t.init(cachedir_al.items);
    defer server.cleanup() catch unreachable;
    server.saveDatas(&[_]server_t.stored_t{0}**server_t.num_saved);
    g_server = &server;
    try server.runServerFunc(runServer);
    g_server = null;
}

fn runServer(server: *server_t) server_t.ClientRequestErrors!void {
    var statBuf: [1<<12]u8 = undefined;
    const statfile = std.fs.openFileAbsolute("/proc/stat", .{ .mode = .read_only }) catch return error.FileError;
    defer statfile.close();
    var statreader = statfile.reader(&statBuf);
    const saved = server.getDatas();
    var tosave: [server_t.num_saved]server_t.stored_t = undefined;
    var percent: [server_t.num_print_perc]server_t.stored_t = undefined;
    var cpu_percents: [server_t.num_graph_perc]server_t.percent_t = undefined;

    //var buf: [100]u8 = undefined;
    // user nice system idle iowait irq softirq steal guest guest_nice
    const active_inds = [_]bool{ true, true, true, false, false, true, true, true, true, true };
    const total_inds = [_]bool{ true, true, true, true, true, true, true, true, false, false };
    var cpu_line: usize = 0;
    while (cpu_line < server_t.num_graph_perc + server_t.num_print_perc) : (cpu_line += 1) {
        const line = statreader.interface.takeDelimiterExclusive('\n') catch return error.ReadError;
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
            const usage = std.fmt.parseUnsigned(server_t.stored_t, colstr, 10) catch return error.ReadError;
            ind = spaceind + 1;
            if (total_inds[colnum]) {
                total += usage;
                if (active_inds[colnum]) {
                    active += usage;
                }
            }
        }
        const perc = if ((total <= saved[cpu_line * 2 + 1]) or (active < saved[cpu_line * 2]))
            0
        else
            ((active - saved[cpu_line * 2]) * 100) / (total - saved[cpu_line * 2 + 1]);
        //var perc: server_t.stored_t = 0;
        //if ((total <= saved[cpu_line * 2 + 1]) or (active < saved[cpu_line * 2])) {
        //    std.debug.print("prev active: {}, total: {}; curr active: {}, total: {} ('{s}' -> '{s}')\n", .{ saved[cpu_line * 2], saved[cpu_line * 2 + 1], active, total, line });
        //} else {
        //    perc = ((active - saved[cpu_line * 2]) * 100) / (total - saved[cpu_line * 2 + 1]);
        //}
        if (cpu_line >= server_t.num_print_perc) {
            cpu_percents[cpu_line - server_t.num_print_perc] = @truncate(perc);
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

fn sigHandler(signal: c_int) align(1) callconv(.c) void {
    // TODO figure out a way to do this other than a global var
    if (g_server) |server| {
        server.stopRunning();
        //server.cleanup() catch unreachable;
    }
    const dfl = std.posix.Sigaction{
        .handler = .{ .handler = std.posix.SIG.DFL },
        .mask = std.posix.sigemptyset(),
        .flags = 0,
    };
    std.posix.sigaction(@intCast(signal), &dfl, null);
}

fn setupSignals() void {
    const act = std.posix.Sigaction{
        .handler = .{ .handler = sigHandler },
        .mask = std.posix.sigemptyset(),
        .flags = 0,
    };
    std.posix.sigaction(std.posix.SIG.HUP, &act, null);
    std.posix.sigaction(std.posix.SIG.TERM, &act, null);
    std.posix.sigaction(std.posix.SIG.INT, &act, null);
}
