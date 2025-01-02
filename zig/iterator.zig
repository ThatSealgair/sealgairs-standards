const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const testing = std.testing;

/// An Iterator provides sequential access to elements in a slice.
/// It offers various operations like mapping, filtering, and reducing
/// that can be chained together for complex data transformations.
///
/// Example:
/// ```
/// var numbers = [_]i32{1, 2, 3, 4, 5};
/// var iter = Iterator(i32).init(&numbers);
/// while (iter.next()) |num| {
///     // Process each number
/// }
/// ```
pub fn Iterator(comptime T: type) type {
    return struct {
        items: []const T,
        index: usize,

        const Self = @This();

        /// Creates a new iterator from a slice of items
        pub fn init(items: []const T) Self {
            return .{
                .items = items,
                .index = 0,
            };
        }

        /// Returns the next item in the sequence and advances the iterator.
        /// Returns null when there are no more items.
        pub fn next(self: *Self) ?T {
            if (self.index >= self.items.len) return null;
            const item = self.items[self.index];
            self.index += 1;
            return item;
        }

        /// Returns the next item without advancing the iterator.
        /// Returns null if there are no more items.
        pub fn peek(self: Self) ?T {
            if (self.index >= self.items.len) return null;
            return self.items[self.index];
        }

        /// Returns the number of items remaining in the iterator
        pub fn count(self: Self) usize {
            return self.items.len - self.index;
        }

        /// Advances the iterator by n positions.
        /// If n would move past the end, moves to the end.
        pub fn skip(self: *Self, n: usize) void {
            const new_index = @min(self.index + n, self.items.len);
            self.index = new_index;
        }

        /// Takes up to n items from the iterator and returns them in an ArrayList.
        /// If fewer than n items remain, returns all remaining items.
        /// Caller owns returned ArrayList.
        pub fn take(self: *Self, allocator: Allocator, n: usize) !ArrayList(T) {
            var result = ArrayList(T).init(allocator);
            errdefer result.deinit();

            var taken: usize = 0;
            while (taken < n) : (taken += 1) {
                const item = self.next() orelse break;
                try result.append(item);
            }
            return result;
        }

        /// Maps each remaining item using the provided function and collects
        /// results into an ArrayList.
        /// Caller owns returned ArrayList.
        pub fn map(self: *Self, allocator: Allocator, comptime Ret: type, comptime func: fn (T) Ret) !ArrayList(Ret) {
            var result = ArrayList(Ret).init(allocator);
            errdefer result.deinit();

            while (self.next()) |item| {
                try result.append(func(item));
            }
            return result;
        }

        /// Maps each remaining item using a function that can fail.
        /// If the function returns an error for any item, that error is returned.
        /// Caller owns returned ArrayList.
        pub fn mapTry(self: *Self, allocator: Allocator, comptime Ret: type, comptime E: type, comptime func: fn (T) E!Ret) !ArrayList(Ret) {
            var result = ArrayList(Ret).init(allocator);
            errdefer result.deinit();

            while (self.next()) |item| {
                try result.append(try func(item));
            }
            return result;
        }

        /// Filters remaining items using the provided predicate function.
        /// Only items for which pred returns true are included in result.
        /// Caller owns returned ArrayList.
        pub fn filter(self: *Self, allocator: Allocator, comptime pred: fn (T) bool) !ArrayList(T) {
            var result = ArrayList(T).init(allocator);
            errdefer result.deinit();

            while (self.next()) |item| {
                if (pred(item)) {
                    try result.append(item);
                }
            }
            return result;
        }

        /// Reduces remaining items to a single value using an accumulator function.
        /// The function is called for each item with the current accumulator value
        /// and the item, and should return the new accumulator value.
        pub fn reduce(self: *Self, comptime Acc: type, initial: Acc, comptime func: fn (Acc, T) Acc) Acc {
            var acc = initial;
            while (self.next()) |item| {
                acc = func(acc, item);
            }
            return acc;
        }

        /// Returns the first item for which pred returns true, or null if no
        /// matching item is found.
        pub fn find(self: *Self, comptime pred: fn (T) bool) ?T {
            while (self.next()) |item| {
                if (pred(item)) return item;
            }
            return null;
        }

        /// Returns true if pred returns true for any remaining item
        pub fn any(self: *Self, comptime pred: fn (T) bool) bool {
            return self.find(pred) != null;
        }

        /// Returns true if pred returns true for all remaining items
        pub fn all(self: *Self, comptime pred: fn (T) bool) bool {
            while (self.next()) |item| {
                if (!pred(item)) return false;
            }
            return true;
        }

        /// Returns true if pred returns false for all remaining items
        pub fn none(self: *Self, comptime pred: fn (T) bool) bool {
            return !self.any(pred);
        }

        /// Chains this iterator with another iterator of the same type.
        /// Returns an ArrayList containing all items from this iterator
        /// followed by all items from the other iterator.
        /// Caller owns returned ArrayList.
        pub fn chain(self: *Self, allocator: Allocator, other: *Self) !ArrayList(T) {
            var result = ArrayList(T).init(allocator);
            errdefer result.deinit();

            while (self.next()) |item| {
                try result.append(item);
            }
            while (other.next()) |item| {
                try result.append(item);
            }
            return result;
        }

        /// Collects all remaining items into an ArrayList.
        /// Caller owns returned ArrayList.
        pub fn collect(self: *Self, allocator: Allocator) !ArrayList(T) {
            var result = ArrayList(T).init(allocator);
            errdefer result.deinit();

            while (self.next()) |item| {
                try result.append(item);
            }
            return result;
        }

        /// Helper type for zip operation
        fn ZipResult(comptime U: type) type {
            return struct {
                first: T,
                second: U,
            };
        }

        /// Combines elements from this iterator with another iterator.
        /// Returns an ArrayList of structs containing pairs of items,
        /// one from each iterator. Stops when either iterator is exhausted.
        /// Caller owns returned ArrayList.
        pub fn zip(self: *Self, comptime U: type, allocator: Allocator, other: *Iterator(U)) !ArrayList(ZipResult(U)) {
            var result = ArrayList(ZipResult(U)).init(allocator);
            errdefer result.deinit();

            while (true) {
                const item1 = self.next() orelse break;
                const item2 = other.next() orelse break;
                try result.append(.{
                    .first = item1,
                    .second = item2,
                });
            }
            return result;
        }
    };
}

test "Iterator - basic operations" {
    var numbers = [_]i32{ 1, 2, 3, 4, 5 };
    var iter = Iterator(i32).init(&numbers);

    try testing.expectEqual(@as(usize, 5), iter.count());
    try testing.expectEqual(@as(?i32, 1), iter.peek());
    try testing.expectEqual(@as(?i32, 1), iter.next());
    try testing.expectEqual(@as(usize, 4), iter.count());
    try testing.expectEqual(@as(?i32, 2), iter.peek());
}

test "Iterator - empty iterator" {
    var empty = [_]i32{};
    var iter = Iterator(i32).init(&empty);

    try testing.expectEqual(@as(usize, 0), iter.count());
    try testing.expectEqual(@as(?i32, null), iter.peek());
    try testing.expectEqual(@as(?i32, null), iter.next());
}

test "Iterator - skip" {
    var numbers = [_]i32{ 1, 2, 3, 4, 5 };
    var iter = Iterator(i32).init(&numbers);

    iter.skip(2);
    try testing.expectEqual(@as(?i32, 3), iter.next());
    try testing.expectEqual(@as(usize, 2), iter.count());

    // Test skipping past end
    iter.skip(10);
    try testing.expectEqual(@as(?i32, null), iter.next());
    try testing.expectEqual(@as(usize, 0), iter.count());
}

test "Iterator - take" {
    var numbers = [_]i32{ 1, 2, 3, 4, 5 };
    var iter = Iterator(i32).init(&numbers);

    const allocator = testing.allocator;

    // Take fewer than available
    var result = try iter.take(allocator, 3);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 3), result.items.len);
    try testing.expectEqual(@as(i32, 1), result.items[0]);
    try testing.expectEqual(@as(i32, 2), result.items[1]);
    try testing.expectEqual(@as(i32, 3), result.items[2]);

    // Take more than remaining
    var remaining = try iter.take(allocator, 10);
    defer remaining.deinit();

    try testing.expectEqual(@as(usize, 2), remaining.items.len);
}

test "Iterator - map" {
    var numbers = [_]i32{ 1, 2, 3 };
    var iter = Iterator(i32).init(&numbers);

    const double = struct {
        fn func(x: i32) i32 {
            return x * 2;
        }
    }.func;

    const allocator = testing.allocator;
    var result = try iter.map(allocator, i32, double);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 3), result.items.len);
    try testing.expectEqual(@as(i32, 2), result.items[0]);
    try testing.expectEqual(@as(i32, 4), result.items[1]);
    try testing.expectEqual(@as(i32, 6), result.items[2]);
}

test "Iterator - mapTry" {
    var numbers = [_]i32{ 1, 2, 3 };
    var iter = Iterator(i32).init(&numbers);

    const maybeDouble = struct {
        fn func(x: i32) !i32 {
            if (x == 2) return error.InvalidInput;
            return x * 2;
        }
    }.func;

    const allocator = testing.allocator;
    try testing.expectError(error.InvalidInput, iter.mapTry(
        allocator,
        i32,
        error{InvalidInput},
        maybeDouble,
    ));
}

test "Iterator - filter" {
    var numbers = [_]i32{ 1, 2, 3, 4, 5 };
    var iter = Iterator(i32).init(&numbers);

    const isEven = struct {
        fn func(x: i32) bool {
            return @mod(x, 2) == 0;
        }
    }.func;

    const allocator = testing.allocator;
    var result = try iter.filter(allocator, isEven);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 2), result.items.len);
    try testing.expectEqual(@as(i32, 2), result.items[0]);
    try testing.expectEqual(@as(i32, 4), result.items[1]);
}

test "Iterator - reduce" {
    var numbers = [_]i32{ 1, 2, 3, 4, 5 };
    var iter = Iterator(i32).init(&numbers);

    const sum = struct {
        fn func(acc: i32, x: i32) i32 {
            return acc + x;
        }
    }.func;

    const result = iter.reduce(i32, 0, sum);
    try testing.expectEqual(@as(i32, 15), result);
}

test "Iterator - find" {
    var numbers = [_]i32{ 1, 2, 3, 4, 5 };
    var iter = Iterator(i32).init(&numbers);

    const isThree = struct {
        fn func(x: i32) bool {
            return x == 3;
        }
    }.func;

    try testing.expectEqual(@as(?i32, 3), iter.find(isThree));

    const isSeven = struct {
        fn func(x: i32) bool {
            return x == 7;
        }
    }.func;

    try testing.expectEqual(@as(?i32, null), iter.find(isSeven));
}

test "Iterator - any/all/none" {
    var numbers = [_]i32{ 1, 2, 3, 4, 5 };

    const isEven = struct {
        fn func(x: i32) bool {
            return @mod(x, 2) == 0;
        }
    }.func;

    const isNegative = struct {
        fn func(x: i32) bool {
            return x < 0;
        }
    }.func;

    {
        var iter = Iterator(i32).init(&numbers);
        try testing.expect(iter.any(isEven));
    }
    {
        var iter = Iterator(i32).init(&numbers);
        try testing.expect(!iter.all(isEven));
    }
    {
        var iter = Iterator(i32).init(&numbers);
        try testing.expect(iter.none(isNegative));
    }
}

test "Iterator - chain" {
    var first = [_]i32{ 1, 2 };
    var second = [_]i32{ 3, 4 };
    var iter1 = Iterator(i32).init(&first);
    var iter2 = Iterator(i32).init(&second);

    const allocator = testing.allocator;
    var result = try iter1.chain(allocator, &iter2);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 4), result.items.len);
    try testing.expectEqual(@as(i32, 1), result.items[0]);
    try testing.expectEqual(@as(i32, 2), result.items[1]);
    try testing.expectEqual(@as(i32, 3), result.items[2]);
    try testing.expectEqual(@as(i32, 4), result.items[3]);
}

test "Iterator - collect" {
    var numbers = [_]i32{ 1, 2, 3 };
    var iter = Iterator(i32).init(&numbers);

    const allocator = testing.allocator;
    var result = try iter.collect(allocator);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 3), result.items.len);
    try testing.expectEqual(@as(i32, 1), result.items[0]);
    try testing.expectEqual(@as(i32, 2), result.items[1]);
    try testing.expectEqual(@as(i32, 3), result.items[2]);
}

test "Iterator - zip" {
    var numbers = [_]i32{ 1, 2, 3 };
    var letters = [_]u8{ 'a', 'b', 'c' };
    var iter1 = Iterator(i32).init(&numbers);
    var iter2 = Iterator(u8).init(&letters);

    const allocator = testing.allocator;
    var result = try iter1.zip(u8, allocator, &iter2);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 3), result.items.len);
    try testing.expectEqual(@as(i32, 1), result.items[0].first);
    try testing.expectEqual(@as(u8, 'a'), result.items[0].second);
    try testing.expectEqual(@as(i32, 2), result.items[1].first);
    try testing.expectEqual(@as(u8, 'b'), result.items[1].second);
    try testing.expectEqual(@as(i32, 3), result.items[2].first);
    try testing.expectEqual(@as(u8, 'c'), result.items[2].second);
}

test "Iterator - zip with unequal lengths" {
    var numbers = [_]i32{ 1, 2, 3 };
    var letters = [_]u8{ 'a', 'b' };
    var iter1 = Iterator(i32).init(&numbers);
    var iter2 = Iterator(u8).init(&letters);

    const allocator = testing.allocator;
    var result = try iter1.zip(u8, allocator, &iter2);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 2), result.items.len);
}
