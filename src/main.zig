const std = @import("std");
const httpz = @import("httpz");
const sqlite = @import("sqlite");
const helper = @import("helper.zig");
const auth = @import("auth.zig");
const game = @import("game.zig");
const App = @import("app.zig");
const print = std.debug.print;

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

    var pool: std.Thread.Pool = undefined;
    try pool.init(.{ .allocator = allocator, .n_jobs = 12 });
    defer pool.deinit();

    // Global app context/state
    var app = App{ .db = &sqldb, .pool = &pool };

    // Server config
    var server = try httpz.ServerApp(*App).init(allocator, .{ .port = 1950 }, &app);
    server.config.request.max_form_count = 20;
    var router = server.router();

    // Routes
    router.get("hello", hello);
    router.post("auth/register", auth.register);
    router.post("auth/login", auth.login);
    router.post("auth/logout", auth.logout);
    router.get("game/village", game.village);

    // Start server
    try server.listen();
}

fn hello(app: *App, req: *httpz.Request, res: *httpz.Response) !void {
    // 1. Get the session_id from the request
    var cookieBuffer: [128]u8 = undefined;

    const session_id = helper.parseCookie(req, &cookieBuffer, "session_id") catch {
        try res.json(.{ .message = "Cookie not found" }, .{});
        return;
    };

    // 2. Get the corresponding user from the database
    const query =
        \\SELECT username FROM player WHERE session_id = ?
    ;
    var stmt = try app.db.prepare(query);
    defer stmt.deinit();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const row = try stmt.oneAlloc([]const u8, allocator, .{}, .{ .session_id = session_id });

    if (row) |username| {
        try res.json(.{ .message = username }, .{});
    } else {
        try res.json(.{ .message = "User not found" }, .{});
    }
}
