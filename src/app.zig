const std = @import("std");
const sqlite = @import("sqlite");

const App = @This();

db: *sqlite.Db,
