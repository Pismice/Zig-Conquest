const std = @import("std");
const App = @import("app.zig");
const httpz = @import("httpz");
const helper = @import("helper.zig");

pub fn village(app: *App, req: *httpz.Request, res: *httpz.Response) !void {
    // 1. Get the connected user session_id cookie
    var cookieBuffer: [128]u8 = undefined;

    const session_id = helper.parseCookie(req, &cookieBuffer, "session_id") catch {
        try res.json(.{ .message = "Cookie not found" }, .{});
        return;
    };

    _ = session_id;
    _ = app;

    // 2. Get all the corresponding village informations for this session_id
    // const query =
    //     \\SELECT password FROM player WHERE username = ?
    // ;
    // var stmt = try app.db.prepare(query);
    // defer stmt.deinit();

    // var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    // defer arena.deinit();
    // const allocator = arena.allocator();
    // const row = try stmt.oneAlloc([]const u8, allocator, .{}, .{ .username = username });
    // var server_hashed_password: [32]u8 = undefined;
    // if (row) |hash| {
    //     server_hashed_password = hash[0..32].*;
    // }

    // 3. Send a response to the user
    try res.json(.{ .message = "You are now disconnected" }, .{});
}
