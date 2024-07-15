const std = @import("std");
const sqlite = @import("sqlite");
const Event = @import("event.zig");
const Army = @import("army.zig");
const Village = @import("village.zig");

const Battle = @This();

const RawBattle = struct {
    event_id: usize,
    army_attacker_id: usize,
    army_defender_id: usize,
    gold_stolen: u64,
    attacker_lost_units: u64,
    defender_lost_units: u64,
    time_start: i64,
    duration: i64,
    resolved: bool,
};
// TODO pas besoin des 2 structs

army_attacker_id: usize,
army_defender_id: usize,
gold_stolen: u64,
attacker_lost_units: u64,
defender_lost_units: u64,
event_id: usize,
time_start: i64,
duration: i64,
resolved: bool,

// Create a point of view of Event for the Battle
fn event(self: *Battle) Event {
    return Event{
        .id = self.event_id,
        .ptr = self,
        .time_end = null,
    };
}

// Overrided function
pub fn executeEventFn(ptr: *anyopaque) !void {
    const self: *Battle = @ptrCast(@alignCast(ptr));
    _ = self;
    std.debug.print("Executing battle event\n");
}

pub fn persist(self: *Battle, db: *sqlite.Db) !void {
    const query = "UPDATE battles SET army_attacker_id = ?, army_defender_id = ?, gold_stolen = ?, attacker_lost_units = ?, defender_lost_units = ?, event_id = ? WHERE event_id = ?";
    try db.execDynamic(
        query,
        .{},
        .{
            self.army_attacker_id,
            self.army_defender_id,
            self.gold_stolen,
            self.attacker_lost_units,
            self.defender_lost_units,
            self.event_id,
            self.event_id,
        },
    );
}

pub fn resolve(self: *Battle, db: *sqlite.Db, allocator: std.mem.Allocator) !void {
    var attacking_army = try Army.initArmyById(db, allocator, self.army_attacker_id);
    var defending_army = try Army.initArmyById(db, allocator, self.army_defender_id);

    const attacker_power = attacking_army.getPower();
    const defender_power = defending_army.getPower();

    if (attacker_power > defender_power) {
        try defending_army.destory(db);
        // Check if the army was defending a village
        const eventual_defending_place = try defending_army.getDefendingPlace(db, allocator);
        if (eventual_defending_place) |defending_village| {
            // Remove golds from the defending village
            self.gold_stolen = defending_village.gold;
            try defending_village.persist(db);

            // Give those golds to the attacker
            var attacker_village = try Village.initVillageByPlayerId(db, allocator, attacking_army.player_id);
            attacker_village.gold += self.gold_stolen;
            try attacker_village.persist(db);

            // Troops bilan
            self.defender_lost_units = defending_army.nb_cavalry + defending_army.nb_infantry + defending_army.nb_ranged;
            try defending_army.destory(db);
        }
    } else {
        // If its a draw, the defender wins
        self.attacker_lost_units = attacking_army.nb_cavalry + attacking_army.nb_infantry + attacking_army.nb_ranged;
        try attacking_army.destory(db);
    }

    var correspond_event = try Event.initEvent(db, self.event_id);
    correspond_event.resolved = true;
    try correspond_event.persist(db);
    try self.persist(db);
    std.debug.print("A battle has been resolved !\n", .{});
    return;
}

pub fn createBattle(db: *sqlite.Db, battle: Battle) !void {
    var c1 = try db.savepoint("c1");
    // Create the event
    try c1.db.execDynamic("INSERT INTO events(time_start,duration,resolved) VALUES(?,?,0);", .{}, .{ battle.time_start, battle.duration });

    // Create the battle
    try c1.db.execDynamic(
        "INSERT INTO battles(army_attacker_id, army_defender_id, gold_stolen, attacker_lost_units, defender_lost_units, event_id) VALUES(?, ?, ?, ?, ?, ?);",
        .{},
        .{
            battle.army_attacker_id,
            battle.army_defender_id,
            battle.gold_stolen,
            battle.attacker_lost_units,
            battle.defender_lost_units,
            c1.db.getLastInsertRowID(),
        },
    );
    defer c1.commit();
    errdefer c1.rollback();
}

// pub fn initBattleById(db: *sqlite.Db, allocator: std.mem.Allocator, id: usize) !*Battle {
//     const query =
//         \\ select army_attacker_id, army_defender_id, gold_stolen, attacker_lost_units, defender_lost_units, event_id from battles
//         \\ inner join events on events.id = battles.event_id
//         \\ where event_id = ?
//     ;
//     var stmt = try db.prepare(query);
//     defer stmt.deinit();
//
//     const row = try stmt.oneAlloc(Battle, allocator, .{}, .{ .event_id = id });
//     const battle: *Battle = try allocator.create(Battle);
//     if (row) |r| {
//         battle.* = r;
//     } else {
//         return error.NotBattleFound;
//     }
//
//     return battle;
// }

pub fn getAllBattlesInOrder(db: *sqlite.Db, allocator: std.mem.Allocator) ![]Battle {
    var c1 = try db.savepoint("c1");
    defer c1.commit();
    errdefer c1.rollback();

    const q = " select count(event_id) from battles inner join events on events.id = battles.event_id limit 1000";
    var s = try c1.db.prepare(q);
    defer s.deinit();
    const count = try s.one(i64, .{}, .{});

    const query =
        \\ select event_id, army_attacker_id, army_defender_id, gold_stolen, attacker_lost_units, defender_lost_units, time_start, duration, resolved from battles
        \\ inner join events on events.id = battles.event_id
        \\ order by (time_start + duration) 
    ;
    var stmt = try c1.db.prepare(query);
    defer stmt.deinit();
    const raw_battles = try stmt.all(RawBattle, allocator, .{}, .{});
    var battles: []Battle = try allocator.alloc(Battle, @intCast(count.?));
    for (raw_battles, 0..) |raw_battle, i| {
        // TODO event
        const event_battle = try Event.initEvent(c1.db, raw_battle.event_id);
        battles[i] = Battle{
            .army_attacker_id = raw_battle.army_attacker_id,
            .army_defender_id = raw_battle.army_defender_id,
            .gold_stolen = raw_battle.gold_stolen,
            .attacker_lost_units = raw_battle.attacker_lost_units,
            .defender_lost_units = raw_battle.defender_lost_units,
            .event_id = raw_battle.event_id,
            .time_start = event_battle.time_start,
            .duration = event_battle.duration,
            .resolved = event_battle.resolved,
        };
    }

    return battles;
}
