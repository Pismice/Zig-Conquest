const std = @import("std");
const sqlite = @import("sqlite");
const Player = @import("player.zig");

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
    var stmt = try db.prepare(query);
    defer stmt.deinit();

    const row = try stmt.oneAlloc(Village, allocator, .{}, .{ .player_id = player_id });
    const village: *Village = try allocator.create(Village);
    if (row) |r| {
        village.* = r;
    }

    return village;
}

pub fn createVillageForPlayer(db: *sqlite.Db, allocator: std.mem.Allocator, player: Player) !void {
    const query2 =
        \\ INSERT INTO villages(name,player_id,x_position,y_position, gold, level, space_capacity) VALUES(?,?,?,?,?,?,?);
    ;
    var stmt = try db.prepare(query2);
    defer stmt.deinit();
    const positions = try findFreeSpaceForVillage(db);
    const vilage_name = try std.fmt.allocPrint(allocator, "{s}' village", .{player.username});
    try stmt.exec(.{}, .{ .name = vilage_name, .player_id = player.id, .x_position = positions[0], .y_position = positions[1], .gold = 100, .level = 1, .space_capacity = 5 });
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
