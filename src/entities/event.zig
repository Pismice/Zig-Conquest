const std = @import("std");
const sqlite = @import("sqlite");

const Event = @This();

id: usize,
time_start: i64, // nb of seconds between 1970 and the end of the event
duration: i64,
ptr: *anyopaque, // pointer to the child event (used for heritage)
executeEventFn: *const fn (ptr: *anyopaque) anyerror!void,

pub fn getRemainingTime(self: Event) !i64 {
    _ = self;
    // negative value means the event is over
    // check if i can use time_end before fetching
    return 0;
}

pub fn executeEvent(self: Event) !void {
    return self.executeEventFn(self.ptr);
}

pub fn getAllTheNextEvents() ![]Event {}
