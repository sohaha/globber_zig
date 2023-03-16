const std = @import("std");
const mem = std.mem;

pub fn validate(glob: []const u8) error{InvalidGlob}!void {
    // Check the length of the glob
    switch (glob.len) {
        // Return an error if the length is 0
        0 => return error.InvalidGlob,
        // Do nothing if the length is 1
        1 => {},
        // Check if the first two characters are '**' and return an error if they are
        2 => if (glob[0] == '*' and glob[1] == '*') return error.InvalidGlob,
        // Check if the rest of the characters contain a '*' and return an error if they do
        else => if (mem.indexOfScalar(u8, glob[1 .. glob.len - 1], '*') != null) {
            return error.InvalidGlob;
        },
    }
}

test validate {
    const testing = std.testing;

    _ = try validate("*");
    _ = try validate("a");
    _ = try validate("*a");
    _ = try validate("a*");
    _ = try validate("*a*");
    _ = try validate("ab");
    _ = try validate("*ab");
    _ = try validate("ab*");
    _ = try validate("*ab*");
    _ = try validate("abc");
    _ = try validate("*abc");
    _ = try validate("abc*");
    _ = try validate("*abc*");

    try testing.expectError(error.InvalidGlob, validate(""));
    try testing.expectError(error.InvalidGlob, validate("**"));
    try testing.expectError(error.InvalidGlob, validate("***"));
    try testing.expectError(error.InvalidGlob, validate("a*c"));
    try testing.expectError(error.InvalidGlob, validate("ab*c*"));
    try testing.expectError(error.InvalidGlob, validate("*ab*c"));
    try testing.expectError(error.InvalidGlob, validate("ab*c"));
    try testing.expectError(error.InvalidGlob, validate("a*bc*"));
    try testing.expectError(error.InvalidGlob, validate("**a"));
    try testing.expectError(error.InvalidGlob, validate("abc**"));
}

pub fn match(s: []const u8, glob: []const u8) bool {
    // Add a runtime safety check
    if (std.debug.runtime_safety) {
        validate(glob) catch unreachable;
    }

    // Check if the length of glob is 1
    if (glob.len == 1) {
        return glob[0] == '*' or mem.eql(u8, s, glob);
    }

    // Check if the first and last characters of glob are '*'
    const suffix_match = glob[0] == '*';
    const prefix_match = glob[glob.len - 1] == '*';

    // Perform different checks based on the result of the previous check
    if (suffix_match and prefix_match) {
        return mem.indexOf(u8, s, glob[1 .. glob.len - 1]) != null;
    } else if (suffix_match) {
        return mem.endsWith(u8, s, glob[1..]);
    } else if (prefix_match) {
        return mem.startsWith(u8, s, glob[0 .. glob.len - 1]);
    } else {
        return mem.eql(u8, s, glob);
    }
}

test match {
    const testing = std.testing;

    try testing.expect(match("", "*"));

    try testing.expect(match("a", "*"));
    try testing.expect(match("a", "*a*"));
    try testing.expect(match("a", "a*"));
    try testing.expect(match("a", "*a"));
    try testing.expect(match("a", "a"));

    try testing.expect(!match("a", "b"));
    try testing.expect(!match("a", "*b*"));
    try testing.expect(!match("a", "b*"));
    try testing.expect(!match("a", "*b"));

    try testing.expect(match("ab", "*"));
    try testing.expect(match("ab", "*a*"));
    try testing.expect(match("ab", "*b*"));
    try testing.expect(match("ab", "a*"));
    try testing.expect(match("ab", "*b"));
    try testing.expect(match("ab", "*ab*"));
    try testing.expect(match("ab", "ab*"));
    try testing.expect(match("ab", "*ab"));
    try testing.expect(match("ab", "ab"));

    try testing.expect(!match("ab", "b*"));
    try testing.expect(!match("ab", "*a"));
    try testing.expect(!match("ab", "*c*"));
    try testing.expect(!match("ab", "c*"));
    try testing.expect(!match("ab", "*c"));
    try testing.expect(!match("ab", "ac"));
    try testing.expect(!match("ab", "*ac*"));
    try testing.expect(!match("ab", "ac*"));
    try testing.expect(!match("ab", "*ac"));

    try testing.expect(match("abc", "*"));
    try testing.expect(match("abc", "*a*"));
    try testing.expect(match("abc", "*b*"));
    try testing.expect(match("abc", "*c*"));
    try testing.expect(match("abc", "a*"));
    try testing.expect(match("abc", "*c"));
    try testing.expect(match("abc", "*ab*"));
    try testing.expect(match("abc", "ab*"));
    try testing.expect(match("abc", "*bc*"));
    try testing.expect(match("abc", "*bc"));
    try testing.expect(match("abc", "*abc*"));
    try testing.expect(match("abc", "abc*"));
    try testing.expect(match("abc", "*abc"));
    try testing.expect(match("abc", "abc"));

    try testing.expect(!match("abc", "*a"));
    try testing.expect(!match("abc", "*b"));
    try testing.expect(!match("abc", "b*"));
    try testing.expect(!match("abc", "c*"));
    try testing.expect(!match("abc", "*ab"));
    try testing.expect(!match("abc", "bc*"));
    try testing.expect(!match("abc", "*d*"));
    try testing.expect(!match("abc", "d*"));
    try testing.expect(!match("abc", "*d"));
}

pub fn order(a: []const u8, b: []const u8) std.math.Order {
    // Validate the inputs a and b
    if (std.debug.runtime_safety) {
        validate(a) catch unreachable;
        validate(b) catch unreachable;
    }

    // Check if both inputs are "*"
    if (mem.eql(u8, a, "*") and mem.eql(u8, b, "*")) {
        return .eq;
    } else if (mem.eql(u8, a, "*")) {
        return .gt;
    } else if (mem.eql(u8, b, "*")) {
        return .lt;
    }

    // Count the number of "*" in each input
    const count_a = @as(u2, @boolToInt(a[0] == '*')) + @boolToInt(a[a.len - 1] == '*');
    const count_b = @as(u2, @boolToInt(b[0] == '*')) + @boolToInt(b[b.len - 1] == '*');

    // Compare the number of "*" in each input
    if (count_a == 0 and count_b == 0) {
        return .eq;
    } else if (count_a == count_b) {
        // Compare the length of each input
        return std.math.order(b.len, a.len);
    } else {
        return std.math.order(count_a, count_b);
    }
}

test order {
    const testing = std.testing;
    const Order = std.math.Order;

    try testing.expectEqual(Order.eq, order("*", "*"));
    try testing.expectEqual(Order.eq, order("*a*", "*b*"));
    try testing.expectEqual(Order.eq, order("a*", "*b"));
    try testing.expectEqual(Order.eq, order("*a", "*b"));
    try testing.expectEqual(Order.eq, order("*a", "b*"));
    try testing.expectEqual(Order.eq, order("a*", "b*"));

    const descending = [_][]const u8{
        "*",
        "*a*",
        "*b*",
        "*a*",
        "*ab*",
        "*bab*",
        "*a",
        "b*",
        "*b",
        "*a",
        "a",
        "bababab",
        "b",
        "a",
    };

    for (descending, 0..) |a, i| {
        for (descending[i..]) |b| {
            try testing.expect(order(a, b) != .lt);
        }
    }

    var ascending = descending;
    mem.reverse([]const u8, &ascending);

    for (ascending, 0..) |a, i| {
        for (ascending[i..]) |b| {
            try testing.expect(order(a, b) != .gt);
        }
    }
}
