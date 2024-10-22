const std = @import("std");
const sqlite = @import("sqlite");

// Make the whole file the Player struct
const Player = @This();

// Used to return to the user the ranking of the players without giving authentification informations
const Result = struct {
    username: []const u8,
    gold: i32,
};

// Fields of the Player struct
id: usize,
username: []const u8,
password: [32]u8,
session_id: [32]u8,

// Function to update the state of the Player in the database, common to most entities
pub fn persist(self: *Player, db: *sqlite.Db) !void {
    const query =
        \\UPDATE player SET username = ?, password = ?, session_id = ? WHERE id = ?
    ;
    var stmt = try db.prepare(query);
    defer stmt.deinit();

    try stmt.exec(.{}, .{
        .username = self.username,
        .password = self.password,
        .session_id = self.session_id,
        .id = self.id,
    });
}

// Return a Player object fetched by the database
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
    } else {
        return error.PlayerNotFoundInDb;
    }

    return player;
}

// Same as above but with different parameter
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

// Function on the entity that is going to be called in files like game.zig where the basic logic of the game is, this is done to avoid having SQL queries in the main logic file of the server
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

pub fn all(db: *sqlite.Db, allocator: std.mem.Allocator) ![]Result {
    const query =
        \\ select username, villages.gold, villages.x_position, villages.y_position, villages.level, villages.name from player
        \\ inner join villages on villages.player_id = player.id
        \\ order by villages.gold desc;
    ;
    var stmt = try db.prepare(query);
    defer stmt.deinit();

    const players = try stmt.all(Result, allocator, .{}, .{});

    return players;
}
