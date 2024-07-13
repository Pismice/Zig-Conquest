const std = @import("std");
const sqlite = @import("sqlite");

const Army = @This();

id: usize,
nb_ranged: u32,
nb_cavalry: u32,
nb_infantry: u32,
player_id: usize,



pub fn createArmyForPlayer(db: *sqlite.Db, player_id: usize) !void {
    // The army is owned by the village AND by the player
    const query2 =
        \\ INSERT INTO armies(nb_ranged, nb_cavalry, nb_infantry, player_id) VALUES(?,?,?,?);
    ;
    var stmt = try db.prepare(query2);
    defer stmt.deinit();
    try stmt.exec(.{}, .{ .nb_ranged = 10, .nb_cavalry = 10, .nb_infantry = 20, .player_id = player_id });
}

pub fn initArmyById(db: *sqlite.Db, allocator: std.mem.Allocator, id: usize) !*Army {
    const query =
        \\SELECT id, nb_ranged, nb_cavalry, nb_infantry, player_id FROM armies WHERE id = ?
    ;
    var stmt = try db.prepare(query);
    defer stmt.deinit();

    const row = try stmt.oneAlloc(Army, allocator, .{}, .{ .id = id });
    const army: *Army = try allocator.create(Army);
    if (row) |r| {
        army.* = r;
    } else {
        return error.ArmyNotFound;
    }

    return army;
}
