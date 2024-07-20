const std = @import("std");
const sqlite = @import("sqlite");
const Event = @import("event.zig");
const Army = @import("army.zig");
const Village = @import("village.zig");

const RessourcesTransfer = @This();

// Ressource transfer specific fields
giver_village_id: usize,
receiver_village_id: usize,
golds_given: u64,

// Events general fields
event_ressources_transfer_id: usize,
time_start: i64,
duration: i64,
resolved: bool,

// Create a point of view of Event for the Battle
pub fn event(self: *RessourcesTransfer) Event {
    return Event{
        .id = self.event_ressources_transfer_id,
        .time_start = self.time_start,
        .duration = self.duration,
        .ptr = self,
        .executeEventFn = executeEventFn,
    };
}

// Overrided function
pub fn executeEventFn(ptr: *anyopaque, db: *sqlite.Db, allocator: std.mem.Allocator) !void {
    const self: *RessourcesTransfer = @ptrCast(@alignCast(ptr));
    const target_village = try Village.initVillageById(db, allocator, self.receiver_village_id);
    target_village.gold += self.golds_given;
    try target_village.persist(db);
    self.resolved = true;
    try self.persist(db);
    return;
}

pub fn initRessourcesTransferById(db: *sqlite.Db, allocator: std.mem.Allocator, id: usize) !*RessourcesTransfer {
    const query =
        \\ select giver_village_id, receiver_village_id, golds_given, event_ressources_transfer_id, time_start, duration, resolved
        \\ from ressources_transfers
        \\ inner join events on events.id = ressources_transfers.event_ressources_transfer_id
        \\ where event_ressources_transfer_id = ?
        \\ order by (time_start + duration) 
    ;
    var stmt = try db.prepare(query);
    defer stmt.deinit();
    const row = try stmt.oneAlloc(RessourcesTransfer, allocator, .{}, .{ .event_ressources_transfer_id = id });
    const ressources_transfer: *RessourcesTransfer = try allocator.create(RessourcesTransfer);
    if (row) |r| {
        ressources_transfer.* = r;
        return ressources_transfer;
    } else {
        return error.RessourcesTransferNotFoundInDb;
    }
}

pub fn persist(self: *RessourcesTransfer, db: *sqlite.Db) !void {
    // FIXME la cest fait pour les battles
    const query = "UPDATE ressources_transfers SET giver_village_id = ?, receiver_village_id = ?, golds_given = ? WHERE event_ressources_transfer_id = ?";

    try db.execDynamic(
        query,
        .{},
        .{
            self.giver_village_id,
            self.receiver_village_id,
            self.golds_given,
            self.event_ressources_transfer_id,
        },
    );

    const query2 = "UPDATE events SET resolved = ? WHERE id = ?";

    try db.execDynamic(
        query2,
        .{},
        .{
            self.resolved,
            self.event_ressources_transfer_id,
        },
    );
}

pub fn createRessourcesTransfer(db: *sqlite.Db, ressource_transfer: RessourcesTransfer) !void {
    var c1 = try db.savepoint("c1");
    // Create the event
    try c1.db.execDynamic("INSERT INTO events(time_start,duration,resolved) VALUES(?,?,0);", .{}, .{ ressource_transfer.time_start, ressource_transfer.duration });

    // Create the ressources transfer
    try c1.db.execDynamic(
        "INSERT INTO ressources_transfers(event_ressources_transfer_id, giver_village_id, receiver_village_id, golds_given) VALUES(?, ?, ?, ?);",
        .{},
        .{
            c1.db.getLastInsertRowID(),
            ressource_transfer.giver_village_id,
            ressource_transfer.receiver_village_id,
            ressource_transfer.golds_given,
        },
    );
    defer c1.commit();
    errdefer c1.rollback();
}
