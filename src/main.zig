const std = @import("std");
const httpz = @import("httpz");
const sqlite = @import("sqlite");
const helper = @import("helper.zig");
const auth = @import("auth.zig");
const game = @import("game.zig");
const App = @import("app.zig");
const Player = @import("entities/player.zig");
const Context = @import("context.zig");
const ht = @import("httpz").testing;
const print = std.debug.print;

fn dis_conn(app: *App, action: httpz.Action(Context), req: *httpz.Request, res: *httpz.Response) !void {
    var cookieBuffer: [256]u8 = undefined;
    const session_id = helper.parseCookie(req, &cookieBuffer, "session_id") catch {
        try res.json(.{ .message = "You are not connected !" }, .{});
        return;
    };
    const player = try Player.initPlayerBySessionId(app.db, res.arena, session_id);
    const context = Context{
        .app = app,
        .user_id = player.id,
    };
    return action(context, req, res);
}

fn dis_not_conn(app: *App, action: httpz.Action(Context), req: *httpz.Request, res: *httpz.Response) !void {
    return action(.{ .user_id = null, .app = app }, req, res);
}

pub fn main() !void {
    // Open SQLite database
    var sqldb = try sqlite.Db.init(.{
        .mode = sqlite.Db.Mode{ .File = "mydb.db" },
        .open_flags = .{
            .write = true,
            .create = true,
        },
        .threading_mode = .Serialized, // I cant use multi thread because the HTTP server is already multi-threaded under the hood, making one thread managing multiple connections thus not allowing sqlite MultiThread
    });
    // Not used be could be I i want to access db faster
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    // Global app context/state
    var app = App{ .db = &sqldb };

    // Server config
    var server = try httpz.ServerCtx(*App, Context).init(allocator, .{ .port = 1950 }, &app);
    server.config.request.max_form_count = 20;
    var router = server.router();

    var not_connected = router.group("", .{ .dispatcher = dis_not_conn, .ctx = &app });
    var connected = router.group("", .{ .dispatcher = dis_conn, .ctx = &app });

    // Routes
    not_connected.get("/", welcome);
    not_connected.post("auth/register", auth.register);
    connected.post("auth/login", auth.login);
    connected.post("auth/logout", auth.logout);
    connected.get("game/village", game.villageInfos);
    connected.post("game/create_building", game.createBuilding);

    // Start server
    try server.listen();
}

pub fn welcome(ctx: Context, req: *httpz.Request, res: *httpz.Response) !void {
    const players = try Player.ranking(ctx.app.db, req.arena);
    const msg = try std.fmt.allocPrint(res.arena, "Welcome to my game which currently has {d} players !", .{players.len});
    try res.json(.{msg}, .{});
}

test "simple zig test" {
    try std.testing.expectEqual(3, 1);
}

test "simple hello request" {
    var sqldb = try sqlite.Db.init(.{
        .mode = sqlite.Db.Mode{ .File = "mydb.db" },
        .open_flags = .{
            .write = true,
            .create = true,
        },
        .threading_mode = .Serialized, // I cant use multi thread because the HTTP server is already multi-threaded under the hood, making one thread managing multiple connections thus not allowing sqlite MultiThread
    });
    var app = App{ .db = &sqldb };
    const ctx = .{ .app = &app, .user_id = null };
    var web_test = ht.init(.{});
    defer web_test.deinit();

    try welcome(ctx, web_test.req, web_test.res);
    try web_test.expectStatus(200);
}
