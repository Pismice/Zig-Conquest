const std = @import("std");
const sqlite = @import("sqlite");

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
executeEventFn: *const fn (ptr: *anyopaque) anyerror!void,

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
    _ = self;
    // negative value means the event is over
    // check if i can use time_end before fetching
    return 0;
}

pub fn executeEvent(self: Event) !void {
    return self.executeEventFn(self.ptr);
}

pub fn getAllTheNextEvents(db: *sqlite.Db, allocator: std.mem.Allocator) ![]Event {
    const query =
        \\ select id, time_start, duration from events
        \\ where resolved = 0
        \\ order by (time_start + duration) 
        \\ limit 50
    ;
    var stmt = try db.prepare(query);
    defer stmt.deinit();

    const raw_events = try stmt.all(RawEvent, allocator, .{}, .{});
    _ = raw_events;

    return error.notimple;
}
