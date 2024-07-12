const std = @import("std");
const App = @import("app.zig");
const Context = @import("context.zig");
const Player = @import("entities/player.zig");
const Village = @import("entities/village.zig");
const httpz = @import("httpz");
const sqlite = @import("sqlite");
const helper = @import("helper.zig");

pub fn logout(ctx: Context, req: *httpz.Request, res: *httpz.Response) !void {
    _ = req;
    const query =
        \\UPDATE player SET session_id = NULL WHERE id = ?
    ;
    var stmt = try ctx.app.db.prepare(query);
    defer stmt.deinit();

    try stmt.exec(.{}, .{
        .id = ctx.user_id,
    });

    // 3. Delete the session_id cookie to the client
    res.headers.add("Set-Cookie", "session_id=; Expires=Thu, 01 Jan 1970 00:00:00 GMT");

    // 4. Send a response to the user
    try res.json(.{ .message = "You are now disconnected" }, .{});
}

pub fn login(ctx: Context, req: *httpz.Request, res: *httpz.Response) !void {
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
    var stmt = try ctx.app.db.prepare(query);
    defer stmt.deinit();

    const row = try stmt.oneAlloc([]const u8, req.arena, .{}, .{ .username = username });
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
    var stmt2 = try ctx.app.db.prepare(query2);
    defer stmt2.deinit();

    try stmt2.exec(.{}, .{
        .session_id = session_id,
        .username = username,
    });

    // 5. Send a response to the user with the cookie if successful or not
    res.headers.add("Set-Cookie", "session_id=" ++ session_id);
    try res.json(.{ .message = "You are now connected" }, .{});
}

pub fn register(ctx: Context, req: *httpz.Request, res: *httpz.Response) !void {
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
    var stmt = try ctx.app.db.prepare(query);
    defer stmt.deinit();
    stmt.exec(.{}, .{ .username = username, .password = hashed_password, .session_id = session_id }) catch {
        try res.json(.{ .message = "Error while creating user: username probably already taken" }, .{});
        return;
    };

    // 4. Get the id from the just created player
    const player = try Player.initPlayerBySessionId(ctx.app.db, req.arena, &session_id);

    // 5. Create the village for the player
    Village.createVillageForPlayer(ctx.app.db, req.arena, player.*) catch {
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

test "logout connected user" {}

test "logout not connected user" {}

test "register new user" {}

test "login connected user" {}

test "login not connected user" {}
