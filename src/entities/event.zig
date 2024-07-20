const std = @import("std");
const sqlite = @import("sqlite");
const Battle = @import("battle.zig");
const ResourcesTransfer = @import("ressources_transfer.zig");

const Event = @This();

const RawEvent = struct {
    id: usize,
    time_start: i64,
    duration: i64,
    resolved: bool,

    pub fn persist(self: RawEvent, db: *sqlite.Db) !void {
        const query = "update events set time_start = ?, duration = ?, resolved = ? where id = ?";
        var stmt = try db.prepare(query);
        defer stmt.deinit();

        try stmt.exec(.{}, .{ .time_start = self.time_start, .duration = self.duration, .resolved = self.resolved, .id = self.id });
    }
};

id: usize,
time_start: i64, // nb of seconds between 1970 and the end of the event
duration: i64,
ptr: *anyopaque, // pointer to the child event (used for heritage)
executeEventFn: *const fn (ptr: *anyopaque, db: *sqlite.Db, allocator: std.mem.Allocator) anyerror!void,

pub fn initEvent(db: *sqlite.Db, id: usize) !RawEvent {
    const query =
        \\ select id, time_start, duration, resolved from events
        \\ where id = ?
    ;
    var stmt = try db.prepare(query);
    defer stmt.deinit();

    const raw_event = try stmt.one(RawEvent, .{}, .{id});
    return raw_event.?;
}

pub fn getRemainingTime(self: Event) !i64 {
    // negative value means the event is over
    return std.time.timestamp() - self.time_start;
}

pub fn executeEvent(self: Event, db: *sqlite.Db, allocator: std.mem.Allocator) !void {
    return self.executeEventFn(self.ptr, db, allocator);
}

pub fn getAllTheNextEvents(db: *sqlite.Db, allocator: std.mem.Allocator) ![]Event {
    // Helped by ChatGPT
    const query =
        \\ 
        \\ WITH CTE AS (
        \\     SELECT 
        \\         event_ressources_transfer_id, 
        \\         event_battle_id,
        \\         COUNT(*) OVER() AS total_count
        \\     FROM 
        \\         events
        \\     LEFT JOIN 
        \\         battles 
        \\     ON 
        \\         battles.event_battle_id = events.id
        \\     LEFT JOIN 
        \\         ressources_transfers 
        \\     ON 
        \\         ressources_transfers.event_ressources_transfer_id = events.id
        \\     WHERE 
        \\         resolved = 0
        \\     ORDER BY 
        \\         (time_start + duration)
        \\ )
        \\ SELECT 
        \\     event_ressources_transfer_id, 
        \\     event_battle_id, 
        \\     total_count
        \\ FROM 
        \\     CTE;
    ;
    var stmt = try db.prepare(query);
    defer stmt.deinit();
    const EventsIds = struct {
        event_ressources_transfer_id: ?usize,
        event_battle_id: ?usize,
        total_count: usize,
    };
    const raw_interfaces_events = try stmt.all(EventsIds, allocator, .{}, .{});

    var totals: usize = 0;
    for (raw_interfaces_events) |event| {
        totals = event.total_count;
        break;
    }

    const events = try allocator.alloc(Event, totals);

    for (raw_interfaces_events, 0..totals) |unkown_event, i| {
        if (unkown_event.event_battle_id) |battle_id| {
            const b = try Battle.initBattleById(db, allocator, battle_id);
            events[i] = b.event();
        } else if (unkown_event.event_ressources_transfer_id) |ressources_transfer_id| {
            const r = try ResourcesTransfer.initRessourcesTransferById(db, allocator, ressources_transfer_id);
            events[i] = r.event();
        } else {
            return error.UnkownEventType;
        }
    }

    return events;
}
