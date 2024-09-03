const std = @import("std");
const httpz = @import("httpz");
const sqlite = @import("sqlite");
const helper = @import("helper.zig");
const auth = @import("auth.zig");
const game = @import("game.zig");
const App = @import("app.zig");
const Player = @import("entities/player.zig");
const Building = @import("entities/building.zig");
const Village = @import("entities/village.zig");
const Event = @import("entities/event.zig");
const Battle = @import("entities/battle.zig");
const Context = @import("context.zig");
const ht = @import("httpz").testing;
const print = std.debug.print;

fn dis_conn(app: *App, action: httpz.Action(Context), req: *httpz.Request, res: *httpz.Response) !void {
    var cookieBuffer: [256]u8 = undefined;
    const session_id = helper.parseCookie(req, &cookieBuffer, "session_id") catch {
        try res.json(.{ .message = "You are not connected !" }, .{});
        return;
    };
    const player = Player.initPlayerBySessionId(app.db, res.arena, session_id) catch {
        try res.json(.{ .message = "Your session expired !" }, .{});
        return;
    };
    const context = Context{
        .app = app,
        .user_id = player.id,
    };
    print("Connected user {d}\n", .{player.id});
    return action(context, req, res);
}

fn dis_not_conn(app: *App, action: httpz.Action(Context), req: *httpz.Request, res: *httpz.Response) !void {
    return action(.{ .user_id = null, .app = app }, req, res);
}

fn ressourceProductionPolling(db: *sqlite.Db) !void {
    while (true) {
        //std.debug.print("Polling \n", .{});
        const start = std.time.milliTimestamp();

        const query =
            \\ UPDATE villages
            \\ SET gold = gold + subquery.total_rod
            \\ FROM (
            \\     SELECT villages.id AS village_id, SUM(productivity) AS total_rod
            \\     FROM gold_mines
            \\     INNER JOIN buildings ON building_id = buildings.id
            \\     INNER JOIN villages ON villages.id = buildings.village_id
            \\     GROUP BY villages.id
            \\ ) AS subquery
            \\ WHERE villages.id = subquery.village_id;
        ;
        var stmt = try db.prepareDynamic(query);
        defer stmt.deinit();
        try stmt.exec(.{}, .{});

        const end = std.time.milliTimestamp();
        const elapsed = end - start;
        std.debug.print("Ressources polling took {d}ms\n", .{elapsed});

        std.time.sleep(60 * std.time.ns_per_s);
    }
}

fn eventsPolling(db: *sqlite.Db) !void {
    while (true) {
        const start = std.time.milliTimestamp();
        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arena.deinit();
        const allocator = arena.allocator();

        const events = try Event.getAllTheNextEvents(db, allocator);
        for (events) |event| {
            if (try event.getRemainingTime() <= 0) {
                try event.executeEvent(db, allocator);
            } else {
                break; // this event is not over so the next ones wont be either
            }
        }
        const end = std.time.milliTimestamp();
        const elapsed = end - start;
        std.debug.print("Events polling took {d}ms\n", .{elapsed});
        std.time.sleep(5 * std.time.ns_per_s);
    }
}

var server: httpz.ServerCtx(*App, Context) = undefined;
var start_time: i64 = 0;
var gpa: std.heap.GeneralPurposeAllocator(.{}) = undefined;

pub fn main() !void {
    // Open SQLite database
    var sqldb = try sqlite.Db.init(.{
        .mode = sqlite.Db.Mode{ .File = "mydb.db" },
        .open_flags = .{
            .write = true,
            .create = true,
        },
        .threading_mode = .Serialized, // I cant use multi thread because the HTTP server handles multiple requests on the same thread at the same time
    });
    // Switch to heap page allocator for best performances
    gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    _ = try allocator.alloc(u8, 100);

    // Global app context/state
    var app = App{ .db = &sqldb };

    // Server config
    server = try httpz.ServerCtx(*App, Context).init(allocator, .{ .port = 1950, .cors = .{ .origin = "http://localhost:5173", .headers = "content-type", .methods = "GET, POST", .max_age = "300" } }, &app);
    server.config.request.max_form_count = 20;
    var router = server.router();
    //    defer router.deinit(allocator);

    var not_connected = router.group("", .{ .dispatcher = dis_not_conn, .ctx = &app });
    var connected = router.group("", .{ .dispatcher = dis_conn, .ctx = &app });

    // Routes
    not_connected.get("/", welcome);
    not_connected.post("auth/register", auth.register);
    not_connected.get("game/ranking", game.ranking);
    connected.post("auth/login", auth.login);
    connected.post("auth/logout", auth.logout);
    connected.get("game/village", game.villageInfos);
    connected.post("game/create_building", game.createBuilding);
    connected.post("game/upgrade_building", game.upgradeBuilding);
    connected.post("game/buy_units", game.buyUnits);
    connected.post("game/attack", game.attackVillage);
    connected.post("game/give_ressources", game.giveRessources);

    // Start workers
    _ = try std.Thread.spawn(.{}, ressourceProductionPolling, .{&sqldb});
    _ = try std.Thread.spawn(.{}, eventsPolling, .{&sqldb});

    // Thank you https://github.com/sphaerophoria/ball-machine/blob/5b2083355d7b2202fb0f0b4b98f54811e5b0a6fb/src/main.zig#L301
    var sa = std.posix.Sigaction{
        .handler = .{
            .handler = &signal_handler,
        },
        .mask = std.posix.empty_sigset,
        .flags = 0,
    };
    try std.posix.sigaction(std.posix.SIG.INT, &sa, null);

    // Start server
    start_time = std.time.timestamp();

    try server.listen(); // Blocking call
}

// Equivalent to a defer for the main function
fn signal_handler(_: c_int) align(1) callconv(.C) void {
    std.debug.print("Received SIGINT\n", .{});

    server.stop();
    std.debug.print("Server stopped after {d} seconds\n", .{std.time.timestamp() - start_time});
    server.deinit();

    //_ = gpa.deinit();
    //    if (deinit_status == .leak) {
    //        std.debug.print("Memory leak detected\n", .{});
    //    } else {
    //        std.debug.print("Memory freed correctly\n", .{});
    //    }
    std.process.exit(0); // important in order to kill all the pollings threads
}

fn welcome(ctx: Context, req: *httpz.Request, res: *httpz.Response) !void {
    const players = try Player.ranking(ctx.app.db, req.arena);
    const msg = try std.fmt.allocPrint(res.arena, "Welcome to my game which currently has {d} players !", .{players.len});
    try res.json(.{msg}, .{});
}

test "simple zig test" {
    try std.testing.expectEqual(1, 1);
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
