const std = @import("std");
const App = @import("app.zig");
const Context = @import("context.zig");
const Player = @import("entities/player.zig");
const Village = @import("entities/village.zig");
const Building = @import("entities/building.zig");
const httpz = @import("httpz");
const helper = @import("helper.zig");

pub fn villageInfos(ctx: Context, req: *httpz.Request, res: *httpz.Response) !void {
    const player = try Player.initPlayerById(ctx.app.db, req.arena, ctx.user_id.?);

    // 3. Get all the corresponding village informations for this player id
    const village = try Village.initVillageByPlayerId(ctx.app.db, res.arena, player.id);

    // 3. Send a response to the user
    try res.json(.{village}, .{});
}

pub fn createBuilding(ctx: Context, req: *httpz.Request, res: *httpz.Response) !void {
    _ = req;
    var gm = Building.GoldMine{ .productivity = 1 };
    Building.createBuilding(
        ctx.app.db,
        res.arena,
        Building.GoldMine,
        &gm,
        ctx.user_id.?,
    ) catch |err| {
        std.debug.print("Error while creating building: {any}\n", .{err});
        try res.json(.{ .message = "Error while creating building :D" }, .{});
        return;
    };

    try res.json(.{ .message = "Building created" }, .{});
}
