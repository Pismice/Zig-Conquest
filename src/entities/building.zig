const std = @import("std");
const sqlite = @import("sqlite");

const Building = @This();

pub const GoldMine = struct {
    productivity: u32,
};

id: usize,
level: u16,
space_taken: u16,

pub fn createBuilding(db: *sqlite.Db, allocator: std.mem.Allocator, comptime BuildingType: type, building: *BuildingType, village_id: usize) !void {
    switch (BuildingType) {
        Building.GoldMine => |_| {
            const gm: *GoldMine = @ptrCast(building);
            _ = gm;
            const query = try std.fmt.allocPrint(allocator, "INSERT INTO buildings(level,space_taken,village_id) VALUES(1,0,{d});INSERT INTO gold_mines(building_id,productivity) VALUES(last_insert_rowid(),{d})", .{ village_id, 5 });
            try db.execDynamic(query, .{}, .{});
        },
        else => return error.UnkownBuildingType,
    }
}
