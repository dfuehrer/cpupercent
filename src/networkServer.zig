const std = @import("std");
const percentgraph = @import("percentgraph");

// TODO figure out how to get network stuffs at compile time
const server_t = percentgraph.PercentGraphServer(u64, 3, 2, 2);
var g_server: ?*server_t = null;

pub fn main() !void {
    setupSignals();
    var buf: [128]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buf);
    //defer fba.deinit();
    const alloc = fba.allocator();
    var cachedir_al = try percentgraph.getCacheDir(alloc, "dwmblocks/networkpercent");
    defer cachedir_al.deinit(alloc);
    try cachedir_al.appendSlice(alloc, "/networkpercent");
    var server = try server_t.initUnits(cachedir_al.items, [_]percentgraph.code_t{'b'} ** server_t.num_print_perc);
    //server.setDelimeters(&[_]server_t.code_t{'🔽', '🔼'});
    server.setDelimeters(&[_]percentgraph.code_t{ '🠗', '🠕' });
    defer server.cleanup() catch unreachable;
    server.saveDatas(&[server_t.num_saved]server_t.stored_t{ 0, 0, 0 });
    g_server = &server;
    try server.runServerFunc(runServer);
    g_server = null;
}

fn runServer(server: *server_t) server_t.ClientRequestErrors!void {
    const megabit_rx = 50;
    const megabit_tx = 15;
    const ms2s = 1000;
    const mega = 1000000;
    var buf: [20]u8 = undefined;
    var bytes_len: usize = undefined;
    var rx_bytes: server_t.stored_t = undefined;
    var tx_bytes: server_t.stored_t = undefined;
    const rx_bytes_wifi_file = std.fs.openFileAbsolute("/sys/class/net/wlan0/statistics/rx_bytes", .{ .mode = .read_only }) catch return error.FileError;
    bytes_len = rx_bytes_wifi_file.read(&buf) catch return error.ReadError;
    rx_bytes = std.fmt.parseUnsigned(server_t.stored_t, buf[0 .. bytes_len - 1], 10) catch return error.ReadError;
    rx_bytes_wifi_file.close();
    const tx_bytes_wifi_file = std.fs.openFileAbsolute("/sys/class/net/wlan0/statistics/tx_bytes", .{ .mode = .read_only }) catch return error.FileError;
    bytes_len = tx_bytes_wifi_file.read(&buf) catch return error.ReadError;
    tx_bytes = std.fmt.parseUnsigned(server_t.stored_t, buf[0 .. bytes_len - 1], 10) catch return error.ReadError;
    tx_bytes_wifi_file.close();
    const rx_bytes_ether_file = std.fs.openFileAbsolute("/sys/class/net/enp6s0/statistics/rx_bytes", .{ .mode = .read_only }) catch return error.FileError;
    bytes_len = rx_bytes_ether_file.read(&buf) catch return error.ReadError;
    rx_bytes += std.fmt.parseUnsigned(server_t.stored_t, buf[0 .. bytes_len - 1], 10) catch return error.ReadError;
    rx_bytes_ether_file.close();
    const tx_bytes_ether_file = std.fs.openFileAbsolute("/sys/class/net/enp6s0/statistics/tx_bytes", .{ .mode = .read_only }) catch return error.FileError;
    bytes_len = tx_bytes_ether_file.read(&buf) catch return error.ReadError;
    tx_bytes += std.fmt.parseUnsigned(server_t.stored_t, buf[0 .. bytes_len - 1], 10) catch return error.ReadError;
    tx_bytes_ether_file.close();

    const saved = server.getDatas();
    const prx_bytes = saved[0];
    const ptx_bytes = saved[1];
    const ptime = saved[2];

    const time: server_t.stored_t = @intCast(std.time.milliTimestamp());
    var dt: server_t.stored_t = undefined;
    if (time < ptime) {
        std.debug.print("time reversed! ptime: {}, time: {}\n", .{ ptime, time });
        dt = ptime - time;
    } else {
        dt = time - ptime;
    }

    const rx_bits: server_t.stored_t = (rx_bytes - prx_bytes) * 8 * ms2s / dt;
    const tx_bits: server_t.stored_t = (tx_bytes - ptx_bytes) * 8 * ms2s / dt;
    const rx_percent: server_t.percent_t = @truncate(rx_bits * 100 / megabit_rx / mega);
    const tx_percent: server_t.percent_t = @truncate(tx_bits * 100 / megabit_tx / mega);

    const percents = [server_t.num_print_perc]server_t.percent_t{ rx_percent, tx_percent };
    const network_bits = [server_t.num_graph_perc]server_t.stored_t{ rx_bits, tx_bits };
    const tosave = [server_t.num_saved]server_t.stored_t{ rx_bytes, tx_bytes, time };
    server.setPercents(percents, &network_bits);
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
