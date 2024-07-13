const std = @import("std");
const App = @import("app.zig");
const Context = @import("context.zig");
const Player = @import("entities/player.zig");
const Event = @import("entities/event.zig");
const Battle = @import("entities/battle.zig");
const Village = @import("entities/village.zig");
const Building = @import("entities/building.zig");
const httpz = @import("httpz");
const helper = @import("helper.zig");

pub fn attackVillage(ctx: Context, req: *httpz.Request, res: *httpz.Response) !void {
    // Get the village id from the request
    const AttackInfos = struct {
        source_village_id: usize = 0,
        target_village_id: usize = 0,
        nb_ranged: u32 = 0,
        nb_cavalry: u32 = 0,
        nb_infantry: u32 = 0,
    };
    var attackInfos = AttackInfos{};
    if (try req.json(AttackInfos)) |attack| {
        attackInfos.target_village_id = attack.target_village_id;
        attackInfos.source_village_id = attack.source_village_id;
        attackInfos.nb_ranged = attack.nb_ranged;
        attackInfos.nb_cavalry = attack.nb_cavalry;
        attackInfos.nb_infantry = attack.nb_infantry;
    } else {
        try res.json(.{ .message = "No village id was provided" }, .{});
        return;
    }

    // Fetch the target village
    const target_village = try Village.initVillageById(ctx.app.db, res.arena, attackInfos.target_village_id);
    if (target_village.player_id == ctx.user_id.?) {
        try res.json(.{ .message = "You cannot attack yourself" }, .{});
        return;
    }

    // Fetch the source village
    const source_village = try Village.initVillageById(ctx.app.db, res.arena, attackInfos.source_village_id);
    if (source_village.player_id != ctx.user_id.?) {
        try res.json(.{ .message = "The source village is not yours" }, .{});
        return;
    }

    // Create attacking army
    const troops = Village.Troops{
        .nb_ranged = attackInfos.nb_ranged,
        .nb_cavalry = attackInfos.nb_cavalry,
        .nb_infantry = attackInfos.nb_infantry,
    };
    const attacking_army = source_village.createAttackingArmy(ctx.app.db, req.arena, troops) catch |err| {
        if (err == error.NotEnoughUnitsInTheVillage) {
            try res.json(.{ .message = "Not enough units" }, .{});
            return;
        }
        std.debug.print("Error while creating attacking army: {any}\n", .{err});
        try res.json(.{ .message = "Error while creating attacking army" }, .{});
        return;
    };

    // Create battle between the 2 armies
    const target_army = try target_village.getArmy(ctx.app.db, req.arena);
    const battle = Battle{
        .defender_lost_units = 0,
        .attacker_lost_units = 0,
        .army_attacker_id = attacking_army.id,
        .army_defender_id = target_army.id,
        .gold_stolen = 0,
        .event_id = 0,
    };
    try Battle.createBattle(ctx.app.db, battle);

    // TODO process the attack (battle) /event

    try res.json(.{ .message = "You army is on the way" }, .{});
}

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

pub fn upgradeBuilding(ctx: Context, req: *httpz.Request, res: *httpz.Response) !void {
    // Get the building id from the request
    var b_id: usize = undefined;
    const BuildingInfos = struct {
        building_id: usize,
    };
    if (try req.json(BuildingInfos)) |building| {
        b_id = building.building_id;
    } else {
        try res.json(.{ .message = "No building id was provided" }, .{});
        return;
    }

    // Fetch the building
    const building = try Building.initBuildingById(ctx.app.db, res.arena, b_id);

    // Verifiy that he is the owner of the building
    const owner_id = try building.getOwnerPlayerId(ctx.app.db);
    if (owner_id != ctx.user_id.?) {
        std.debug.print("User {d} /= {d}\n", .{ ctx.user_id.?, owner_id });
        try res.json(.{ .message = "You are not the owner of this building" }, .{});
        // TODO report this because it proably is malicious activity
        return;
    }

    // Upgrade the building
    building.upgradeBuilding(ctx.app.db) catch |err| {
        if (err == error.NotEnoughRessources) {
            try res.json(.{ .message = "Not enough ressources" }, .{});
            return;
        }
        try res.json(.{ .message = "Unexcepted error occured while upgrading the building" }, .{});
        return;
    };
    try res.json(.{ .success = true }, .{});
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
