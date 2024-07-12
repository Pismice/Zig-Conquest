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
    router.post("auth/register", auth.register);
    router.post("auth/login", auth.login);
    router.post("auth/logout", auth.logout);
    router.get("game/village", game.villageInfos);

    // Start server
    try server.listen();
}
