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
    var gm = Building.GoldMine{ .productivity = 1 };
    const village = try Village.initVillageByPlayerId(ctx.app.db, req.arena, ctx.user_id.?);

    village.createBuilding(ctx.app.db, req.arena, Building.GoldMine, &gm) catch |err| {
        std.debug.print("Error while creating building: {any}\n", .{err});
        try res.json(.{ .message = "Error while creating building :D" }, .{});
        return;
    };

    try res.json(.{ .message = "Building created" }, .{});
}

pub fn buyUnits(ctx: Context, req: *httpz.Request, res: *httpz.Response) !void {
    _ = ctx;
    _ = req;
    try res.json(.{ .message = "Not implemented yet" }, .{});
}

pub fn ranking(ctx: Context, req: *httpz.Request, res: *httpz.Response) !void {
    _ = req;
    const players_ranking = try Player.ranking(ctx.app.db, res.arena);
    try res.json(.{players_ranking}, .{});
}
