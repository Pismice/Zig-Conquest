const std = @import("std");
const httpz = @import("httpz");
const sqlite = @import("sqlite");
const helper = @import("helper.zig");
const print = std.debug.print;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

const App = struct {
    db: *sqlite.Db,
    pool: *std.Thread.Pool,
};

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
    router.post("auth/register", register);
    router.post("auth/login", login);
    router.post("auth/logout", logout);

    // Start server
    try server.listen();
}

fn logout(app: *App, req: *httpz.Request, res: *httpz.Response) !void {
    // 1. Get the connected user session_id cookie
    var cookieBuffer: [128]u8 = undefined;

    const session_id = helper.parseCookie(req, &cookieBuffer, "session_id") catch {
        try res.json(.{ .message = "Cookie not found" }, .{});
        return;
    };

    // 2. SET session_id to NULL in the database
    const query =
        \\UPDATE player SET session_id = NULL WHERE session_id = ?
    ;
    var stmt = try app.db.prepare(query);
    defer stmt.deinit();

    try stmt.exec(.{}, .{
        .session_id = session_id,
    });

    // 3. Delete the session_id cookie to the client
    res.headers.add("Set-Cookie", "session_id=; Expires=Thu, 01 Jan 1970 00:00:00 GMT");

    // 4. Send a response to the user
    try res.json(.{ .message = "You are now disconnected" }, .{});
}

fn login(app: *App, req: *httpz.Request, res: *httpz.Response) !void {
    // 1. Get the username and password from the user
    const fd = try req.formData();
    var username: []const u8 = undefined;
    var password: []const u8 = undefined;
    if (fd.get("username")) |u| {
        username = u;
    } else {
        try res.json(.{ .message = "username not found" }, .{});
        return;
    }
    if (fd.get("password")) |p| {
        password = p;
    } else {
        try res.json(.{ .message = "password not found" }, .{});
        return;
    }

    // 2. Hash the given password
    var hashed_password: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(password, &hashed_password, .{});

    // 3. Verify that the username and the password corresponds
    const query =
        \\SELECT password FROM player WHERE username = ?
    ;
    var stmt = try app.db.prepare(query);
    defer stmt.deinit();

    // FIXME change to arena allocator
    const row = try stmt.oneAlloc([]const u8, allocator, .{}, .{ .username = username });
    var server_hashed_password: [32]u8 = undefined;
    if (row) |hash| {
        server_hashed_password = hash[0..32].*;
    }
    if (!std.mem.eql(u8, &server_hashed_password, &hashed_password)) {
        try res.json(.{ .message = "Invalid username or password" }, .{});
        //std.debug.print("{s}\n", .{std.fmt.fmtSliceHexUpper(&hashed_password)});
        return;
    }

    // 4. Refresh the session_id
    var session_id: [32]u8 = undefined;
    // FIXME meme chose que dans register
    const rand = std.crypto.random;
    for (0..32) |d| {
        session_id[d] = rand.intRangeAtMost(u8, 65, 125);
    }
    const query2 =
        \\UPDATE player SET session_id = ? WHERE username = ?
    ;
    var stmt2 = try app.db.prepare(query2);
    defer stmt2.deinit();

    try stmt2.exec(.{}, .{
        .session_id = session_id,
        .username = username,
    });

    // 5. Send a response to the user with the cookie if successful or not
    res.headers.add("Set-Cookie", "session_id=" ++ session_id);
    try res.json(.{ .message = "You are now connected" }, .{});
}

fn register(app: *App, req: *httpz.Request, res: *httpz.Response) !void {
    // 1. Get the username and password from the user
    const fd = try req.formData();
    var username: []const u8 = undefined;
    var password: []const u8 = undefined;
    if (fd.get("username")) |u| {
        username = u;
    } else {
        try res.json(.{ .message = "username not found" }, .{});
        return;
    }
    if (fd.get("password")) |p| {
        password = p;
    } else {
        try res.json(.{ .message = "password not found" }, .{});
        return;
    }

    // 2. Hash the password
    var hashed_password: [32]u8 = undefined;
    var session_id: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(password, &hashed_password, .{});

    // 3. Store the username, hashed password and session_id in the database
    // FIXME std.time.timestamp() is not secure, use std.crypto.random
    // @bitCast(std.time.timestamp())
    // also it seems a bit not scure 35-125 and slow to do it 32 times
    // caracetres dangereux ??
    const rand = std.crypto.random;
    for (0..32) |d| {
        session_id[d] = rand.intRangeAtMost(u8, 65, 125);
    }
    const query = "INSERT INTO player(username,password,session_id) VALUES(?,?,?)";
    var stmt = try app.db.prepare(query);
    defer stmt.deinit();
    // FIXME pour eviter l erreur verifier avec une requete avant ??
    stmt.exec(.{}, .{ .username = username, .password = hashed_password, .session_id = session_id }) catch {
        try res.json(.{ .message = "Username already taken" }, .{});
        return;
    };

    // 4. Send a response to the user with the cookie if successful or not
    print("session_id: {s}\n", .{session_id});
    res.headers.add("Set-Cookie", "session_id=" ++ session_id);
    try res.json(.{ .message = "Success" }, .{});
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

    // FIXME change to arena allocator
    const row = try stmt.oneAlloc([]const u8, allocator, .{}, .{ .session_id = session_id });

    if (row) |username| {
        try res.json(.{ .message = username }, .{});
    } else {
        try res.json(.{ .message = "User not found" }, .{});
    }
}
