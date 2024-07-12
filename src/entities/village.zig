const std = @import("std");
const sqlite = @import("sqlite");

const Village = @This();

id: usize,
name: []const u8,
x_position: u32,
y_position: u32,

// TODO passer un alloc par parametre
pub fn initVillageByPlayerId(db: *sqlite.Db, allocator: std.mem.Allocator, player_id: usize) !*Village {
    const query =
        \\SELECT id, name, x_position, y_position FROM villages WHERE player_id = ?
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
