const std = @import("std");
const sqlite = @import("sqlite");

const Player = @This();

id: usize,
username: []const u8,
password: [32]u8,
session_id: [32]u8,

pub fn initPlayerBySessionId(db: *sqlite.Db, allocator: std.mem.Allocator, s_id: []const u8) !*Player {
    const query =
        \\SELECT id, username, password, session_id FROM player WHERE session_id = ?
    ;
    var stmt = try db.prepare(query);
    defer stmt.deinit();

    const row = try stmt.oneAlloc(Player, allocator, .{}, .{ .session_id = s_id });
    const player: *Player = try allocator.create(Player);
    if (row) |r| {
        player.* = r;
    }

    return player;
}

pub fn initPlayerById(db: *sqlite.Db, allocator: std.mem.Allocator, id: usize) !*Player {
    const query =
        \\SELECT id, username, password, session_id FROM player WHERE id = ?
    ;
    var stmt = try db.prepare(query);
    defer stmt.deinit();

    const row = try stmt.oneAlloc(Player, allocator, .{}, .{ .id = id });
    const player: *Player = try allocator.create(Player);
    if (row) |r| {
        player.* = r;
    }

    return player;
}
