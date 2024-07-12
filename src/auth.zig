const std = @import("std");
const App = @import("app.zig");
const Player = @import("entities/player.zig");
const httpz = @import("httpz");
const sqlite = @import("sqlite");
const helper = @import("helper.zig");

pub fn logout(app: *App, req: *httpz.Request, res: *httpz.Response) !void {
    // 1. Get the connected user session_id cookie
    var cookieBuffer: [256]u8 = undefined;

    const session_id = helper.parseCookie(req, &cookieBuffer, "session_id") catch {
        try res.json(.{ .message = "You are not connected" }, .{});
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

pub fn login(app: *App, req: *httpz.Request, res: *httpz.Response) !void {
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

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
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
    generateSessionId(&session_id);

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

pub fn register(app: *App, req: *httpz.Request, res: *httpz.Response) !void {
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
    generateSessionId(&session_id);
    const query =
        \\ INSERT INTO player(username,password,session_id) VALUES(?,?,?);
    ;
    var stmt = try app.db.prepare(query);
    defer stmt.deinit();
    stmt.exec(.{}, .{ .username = username, .password = hashed_password, .session_id = session_id }) catch {
        try res.json(.{ .message = "Error while creating user: username probably already taken" }, .{});
        return;
    };

    std.debug.print("Insert ok\n", .{});

    // 4. Get the id from the just created player
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const player = try Player.initPlayerBySessionId(app.db, allocator, &session_id);

    // 5. Create the village for the player
    const query2 =
        \\ INSERT INTO villages(name,player_id,x_position,y_position) VALUES(?,?,?,?);
    ;
    var stmt2 = try app.db.prepare(query2);
    defer stmt2.deinit();
    const vilage_name = std.fmt.allocPrint(allocator, "{s}' village", .{username}) catch return;
    const positions = try findFreeSpaceForVillage(app.db);
    stmt2.exec(.{}, .{ .name = vilage_name, .player_id = player.id, .x_position = positions[0], .y_position = positions[1] }) catch {
        try res.json(.{ .message = "Error while creating village" }, .{});
        return;
    };

    // 5. Send a response to the user with the cookie if successful or not
    res.headers.add("Set-Cookie", "session_id=" ++ session_id);
    try res.json(.{ .success = true }, .{});
}

fn generateSessionId(session_id: *[32]u8) void {
    // FIXME bad generation
    const rand = std.crypto.random;
    for (0..32) |d| {
        session_id[d] = rand.intRangeAtMost(u8, 65, 125);
    }
}

fn findFreeSpaceForVillage(db: *sqlite.Db) !struct { u32, u32 } {
    const rand = std.crypto.random;
    var is_space_free: bool = false;
    var x: u32 = undefined;
    var y: u32 = undefined;
    while (!is_space_free) {
        is_space_free = true;
        x = rand.intRangeAtMost(u32, 0, 100);
        y = rand.intRangeAtMost(u32, 0, 100);
        // Check if the space is free
        const query =
            \\SELECT x_position, y_position FROM villages
        ;

        var stmt = try db.prepare(query);
        defer stmt.deinit();

        const row = try stmt.one(
            struct {
                x_position: u32,
                y_position: u32,
            },
            .{},
            .{},
        );
        if (row) |r| {
            if (x == r.x_position and y == r.y_position) {
                is_space_free = false;
                continue;
            }
        }
    }
    return .{ x, y };
}
