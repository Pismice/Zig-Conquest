const std = @import("std");
const App = @import("app.zig");
const Player = @import("./entities/player.zig");
const Village = @import("./entities/village.zig");
const httpz = @import("httpz");
const helper = @import("helper.zig");

pub fn villageInfos(app: *App, req: *httpz.Request, res: *httpz.Response) !void {
    // 1. Get the connected user session_id cookie
    var cookieBuffer: [256]u8 = undefined;

    const session_id = helper.parseCookie(req, &cookieBuffer, "session_id") catch {
        try res.json(.{ .message = "Cookie not found" }, .{});
        return;
    };

    // 2. Find the player id of this session_id
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const player = try Player.initPlayerBySessionId(app.db, allocator, session_id);

    // 3. Get all the corresponding village informations for this player id
    const village = try Village.initVillageByPlayerId(app.db, allocator, player.id);

    // 3. Send a response to the user
    try res.json(.{village}, .{});
}
