const std = @import("std");
const sqlite = @import("sqlite");

const Player = @This();

const Result = struct {
    username: []const u8,
    gold: i32,
};

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

pub fn ranking(db: *sqlite.Db, allocator: std.mem.Allocator) ![]Result {
    const query =
        \\ select username, villages.gold from player
        \\ inner join villages on villages.player_id = player.id
        \\ order by villages.gold desc;
    ;
    var stmt = try db.prepare(query);
    defer stmt.deinit();

    const players = try stmt.all(Result, allocator, .{}, .{});

    return players;
}
