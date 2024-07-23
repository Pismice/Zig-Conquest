const std = @import("std");
const sqlite = @import("sqlite");

const Army = @This();
const Village = @import("village.zig");

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

pub fn getDefendingPlace(self: *Army, db: *sqlite.Db, allocator: std.mem.Allocator) !?*Village {
    const query =
        \\ select villages.id from villages
        \\ inner join player on player.id = villages.player_id
        \\ inner join armies on villages.army_id = armies.id
        \\ where army_id = ?
    ;
    var stmt = try db.prepare(query);
    defer stmt.deinit();

    const row = try stmt.one(usize, .{}, .{ .id = self.id });
    if (row) |r| {
        return try Village.initVillageById(db, allocator, r);
    } else {
        // This army is not defeding any village
        return null;
    }
}

pub fn persist(self: *Army, db: *sqlite.Db) !void {
    const query =
        \\ UPDATE armies SET nb_ranged = ?, nb_cavalry = ?, nb_infantry = ? WHERE id = ?
    ;
    var stmt = try db.prepare(query);
    defer stmt.deinit();
    try stmt.exec(.{}, .{ .nb_ranged = self.nb_ranged, .nb_cavalry = self.nb_cavalry, .nb_infantry = self.nb_infantry, .id = self.id });
}

pub fn delete(self: *Army, db: *sqlite.Db) !void {
    const query =
        \\ DELETE FROM armies WHERE id = ?
    ;
    var stmt = try db.prepare(query);
    defer stmt.deinit();
    try stmt.exec(.{}, .{ .id = self.id });
}

pub fn destory(self: *Army, db: *sqlite.Db) !void {
    const query =
        \\ UPDATE armies SET nb_ranged = 0, nb_cavalry = 0, nb_infantry = 0 WHERE id = ?
    ;
    var stmt = try db.prepare(query);
    defer stmt.deinit();
    try stmt.exec(.{}, .{ .id = self.id });
}

pub fn getPower(self: *Army) u32 {
    return self.nb_ranged + self.nb_cavalry + self.nb_infantry;
}
