const std = @import("std");
const sqlite = @import("sqlite");

const Building = @This();

pub const GoldMine = struct {
    productivity: u32,
};

pub const Price = struct {
    gold: u32,
    space_capacity: u32,
};

id: usize,
level: u16,
space_taken: u16,
village_id: usize,

pub fn initBuildingById(db: *sqlite.Db, allocator: std.mem.Allocator, id: usize) !*Building {
    const query =
        \\SELECT id, level, space_taken, village_id FROM buildings WHERE id = ?
    ;
    var stmt = try db.prepare(query);
    defer stmt.deinit();

    const row = try stmt.oneAlloc(Building, allocator, .{}, .{ .id = id });
    const building: *Building = try allocator.create(Building);
    if (row) |r| {
        building.* = r;
    } else {
        return error.BuildingNotFoundInDb;
    }

    return building;
}

pub fn getOwnerPlayerId(self: *Building, db: *sqlite.Db) !usize {
    const query =
        \\ select player.id from buildings
        \\ inner join villages on villages.id = buildings.village_id
        \\ inner join player on player.id = villages.player_id
        \\ where buildings.id = @lol
    ;
    var stmt = try db.prepare(query);
    defer stmt.deinit();

    std.debug.print("id: {}\n", .{self.id});
    const row = try stmt.one(usize, .{}, .{ .lol = self.id });
    if (row) |r| {
        return r;
    }
    return error.BuildingHasNoOwner;
}

pub fn upgradeBuilding(self: *Building, db: *sqlite.Db) !void {
    // Check how much space and gold it would cost
    const space_needed = 1;
    const gold_needed = self.level * 20;

    var c1 = try db.savepoint("c1");
    // Check if enough space and gold in village
    const query =
        \\ select gold, space_capacity from villages where id = ?
    ;
    std.debug.print("{s}\n", .{query});
    var stmt = try c1.db.prepare(query);
    defer stmt.deinit();

    const row = try stmt.one(Price, .{}, .{ .id = self.village_id });

    var available_ressources: Price = .{ .gold = 0, .space_capacity = 0 };
    if (row) |r| {
        available_ressources = r;
    } else {
        return error.CouldNotFetchAvailableRessources;
    }

    if (gold_needed > available_ressources.gold or space_needed > available_ressources.space_capacity) {
        return error.NotEnoughRessources;
    }

    // If enough update the db
    try c1.db.execDynamic("update villages set gold = gold - ?, space_capacity = space_capacity - ? where id = ?;", .{}, .{ gold_needed, space_needed, self.village_id });
    try c1.db.execDynamic("update buildings set level = level + 1 where id = ?;", .{}, .{self.id});

    // Find the type of the buildling to do the right specific upgrade
    try c1.db.execDynamic("update gold_mines set productivity = productivity + 1 where building_id = ?", .{}, .{self.id});
    // TODO do the same for other buildings

    defer c1.commit();
    errdefer c1.rollback();
}
