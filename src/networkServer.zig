const std = @import("std");
const percentgraph = @import("percentgraph");

// TODO figure out how to get network stuffs at compile time
const server_t = percentgraph.PercentGraphServer(u64, 3, 2, 2);
var g_server: ?*server_t = null;

pub fn main() !void {
    try setupSignals();
    var buf: [100]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buf);
    //defer fba.deinit();
    const alloc = fba.allocator();
    var cachedir_al = try percentgraph.getCacheDir(alloc, "dwmblocks/networkpercent");
    defer cachedir_al.deinit();
    try cachedir_al.appendSlice("/networkpercent");
    var server = try server_t.initUnits(cachedir_al.items, [_]percentgraph.code_t{'b'} ** server_t.num_print_perc);
    //server.setDelimeters(&[_]server_t.code_t{'🔽', '🔼'});
    server.setDelimeters(&[_]percentgraph.code_t{ '🠗', '🠕' });
    defer server.cleanup() catch unreachable;
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
    var reader = rx_bytes_wifi_file.reader();
    bytes_len = reader.readAll(&buf) catch return error.ReadError;
    rx_bytes = std.fmt.parseUnsigned(server_t.stored_t, buf[0 .. bytes_len - 1], 10) catch return error.ReadError;
    rx_bytes_wifi_file.close();
    const tx_bytes_wifi_file = std.fs.openFileAbsolute("/sys/class/net/wlan0/statistics/tx_bytes", .{ .mode = .read_only }) catch return error.FileError;
    reader = rx_bytes_wifi_file.reader();
    bytes_len = reader.readAll(&buf) catch return error.ReadError;
    tx_bytes = std.fmt.parseUnsigned(server_t.stored_t, buf[0 .. bytes_len - 1], 10) catch return error.ReadError;
    tx_bytes_wifi_file.close();
    const rx_bytes_ether_file = std.fs.openFileAbsolute("/sys/class/net/wlan0/statistics/rx_bytes", .{ .mode = .read_only }) catch return error.FileError;
    reader = rx_bytes_ether_file.reader();
    bytes_len = reader.readAll(&buf) catch return error.ReadError;
    rx_bytes += std.fmt.parseUnsigned(server_t.stored_t, buf[0 .. bytes_len - 1], 10) catch return error.ReadError;
    rx_bytes_ether_file.close();
    const tx_bytes_ether_file = std.fs.openFileAbsolute("/sys/class/net/wlan0/statistics/tx_bytes", .{ .mode = .read_only }) catch return error.FileError;
    reader = rx_bytes_ether_file.reader();
    bytes_len = reader.readAll(&buf) catch return error.ReadError;
    tx_bytes += std.fmt.parseUnsigned(server_t.stored_t, buf[0 .. bytes_len - 1], 10) catch return error.ReadError;
    tx_bytes_ether_file.close();

    const saved = server.getDatas();
    const prx_bytes = saved[0];
    const ptx_bytes = saved[1];
    const ptime = saved[2];

    const time = @intCast(server_t.stored_t, std.time.milliTimestamp());

    const rx_bits: server_t.stored_t = (rx_bytes - prx_bytes) * 8 * ms2s / (time - ptime);
    const rx_percent = @truncate(server_t.percent_t, rx_bits * 100 / megabit_rx / mega);
    const tx_bits: server_t.stored_t = (tx_bytes - ptx_bytes) * 8 * ms2s / (time - ptime);
    const tx_percent = @truncate(server_t.percent_t, tx_bits * 100 / megabit_tx / mega);

    const percents = [server_t.num_print_perc]server_t.percent_t{ rx_percent, tx_percent };
    const network_bits = [server_t.num_graph_perc]server_t.stored_t{ rx_bits, tx_bits };
    const tosave = [server_t.num_saved]server_t.stored_t{ rx_bytes, tx_bytes, time };
    server.setPercents(percents, &network_bits);
    server.saveDatas(&tosave);
}

fn sigHandler(signal: c_int) align(1) callconv(.C) void {
    // TODO figure out a way to do this other than a global var
    if (g_server) |server| {
        server.stopRunning();
        //server.cleanup() catch unreachable;
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
