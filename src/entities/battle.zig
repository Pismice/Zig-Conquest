const std = @import("std");
const sqlite = @import("sqlite");
const Event = @import("event.zig");

const Battle = @This();

army_attacker_id: usize,
army_defender_id: usize,
gold_stolen: u64,
attacker_lost_units: u64,
defender_lost_units: u64,
event_id: usize,

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

pub fn createBattle(db: *sqlite.Db, battle: Battle) !void {
    var c1 = try db.savepoint("c1");
    // Create the event
    try c1.db.execDynamic("INSERT INTO events(time_start,duration) VALUES(?,?);", .{}, .{ std.time.timestamp(), 15 });

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

pub fn initBattleById(db: *sqlite.Db, allocator: std.mem.Allocator, id: usize) !*Battle {
    const query =
        \\ select village_attacker_id, village_defender_id, gold_stolen, attacker_lost_units, defender_lost_units, event_id from battles
        \\ inner join events on events.id = battles.event_id
        \\ where event_id = ?
    ;
    var stmt = try db.prepare(query);
    defer stmt.deinit();

    const row = try stmt.oneAlloc(Battle, allocator, .{}, .{ .event_id = id });
    const battle: *Battle = try allocator.create(Battle);
    if (row) |r| {
        battle.* = r;
    } else {
        return error.NotBattleFound;
    }

    return battle;
}
