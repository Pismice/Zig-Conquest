const std = @import("std");
const sqlite = @import("sqlite");
const Player = @import("player.zig");
const Building = @import("building.zig");
const Army = @import("army.zig");

const Village = @This();

id: usize,
name: []const u8,
x_position: u32,
y_position: u32,
gold: u32,
level: u16,
space_capacity: u16,

// TODO passer un alloc par parametre
pub fn initVillageByPlayerId(db: *sqlite.Db, allocator: std.mem.Allocator, player_id: usize) !*Village {
    const query =
        \\SELECT id, name, x_position, y_position, gold, level, space_capacity FROM villages WHERE player_id = ?
    ;
    std.debug.print("query: {s}\n", .{query});
    var stmt = try db.prepare(query);
    defer stmt.deinit();

    const row = try stmt.oneAlloc(Village, allocator, .{}, .{ .player_id = player_id });
    const village: *Village = try allocator.create(Village);
    if (row) |r| {
        village.* = r;
    }

    return village;
}

// pub fn getBuildings(self: *Village, db: *sqlite.Db, allocator: std.mem.Allocator) ![]Building {
//     // TODO implement
// }

pub fn createBuilding(self: *Village, db: *sqlite.Db, allocator: std.mem.Allocator, comptime BuildingType: type, building: *BuildingType) !void {
    switch (BuildingType) {
        Building.GoldMine => |_| {
            const gm: *Building.GoldMine = @ptrCast(building);
            _ = allocator;

            var c1 = try db.savepoint("c1");

            try c1.db.execDynamic("INSERT INTO buildings(level,space_taken,village_id) VALUES(1,0,?);", .{}, .{self.id});
            try c1.db.execDynamic("INSERT INTO gold_mines(building_id,productivity) VALUES(last_insert_rowid(),?);", .{}, .{gm.productivity});
            c1.commit();
        },
        else => return error.UnkownBuildingType,
    }
}

pub fn createVillageForPlayer(db: *sqlite.Db, allocator: std.mem.Allocator, player: Player) !void {
    const positions = try findFreeSpaceForVillage(db);

    var c1 = try db.savepoint("c1");

    try Army.createArmyForPlayer(c1.db, player.id);

    const query2 =
        \\ INSERT INTO villages(name,player_id,x_position,y_position, gold, level, space_capacity, army_id) VALUES(?,?,?,?,?,?,?,?);
    ;
    var stmt = try c1.db.prepare(query2);
    defer stmt.deinit();
    const vilage_name = try std.fmt.allocPrint(allocator, "{s}' village", .{player.username});
    try stmt.exec(.{}, .{ .name = vilage_name, .player_id = player.id, .x_position = positions[0], .y_position = positions[1], .gold = 100, .level = 1, .space_capacity = 5, .army_id = c1.db.getLastInsertRowID() });

    c1.commit();
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
