const httpz = @import("httpz");
const std = @import("std");

pub fn parseCookie(req: *httpz.Request, buffer: []u8, key: []const u8) ![]const u8 {
    var index: usize = 0;
    var w_index: usize = 0;
    var next_word_is_value: bool = false;

    var cookies: []const u8 = undefined;
    if (req.header("cookie")) |c| {
        cookies = c;
    } else {
        return error.CookieNotFound;
    }

    while (index < cookies.len) : ({
        index += 1;
    }) {
        const current_char = cookies[index];
        if (current_char == '=') {
            if (std.mem.eql(u8, key, buffer[0..key.len])) {
                next_word_is_value = true;
            }
            w_index = 0;
        } else if (current_char == ';') {
            // End of value
            if (next_word_is_value) {
                return buffer[0..w_index];
            }
            w_index = 0;
        } else if (current_char == ' ') {
            // White character
            continue;
        } else {
            // Word is building
            buffer[w_index] = current_char;
            w_index += 1;
        }
    }

    if (next_word_is_value) {
        return buffer[0..w_index];
    }

    return error.CookieNotFound;
}
