const std = @import("std");
const sqlite = @import("sqlite");

const Player = @This();

id: usize,
nb_ranged: u32,
nb_cavalry: u32,
nb_infantry: u32,

pub fn createArmyForPlayer(db: *sqlite.Db, player_id: usize) !void {
    // The army is owned by the village AND by the player
    const query2 =
        \\ INSERT INTO armies(nb_ranged, nb_cavalry, nb_infantry, player_id) VALUES(?,?,?,?);
    ;
    var stmt = try db.prepare(query2);
    defer stmt.deinit();
    try stmt.exec(.{}, .{ .nb_ranged = 10, .nb_cavalry = 10, .nb_infantry = 20, .player_id = player_id });
}
