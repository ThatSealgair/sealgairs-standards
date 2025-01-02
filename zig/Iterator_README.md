# Zig Iterator Library

A flexible and efficient iterator implementation for Zig, providing a rich set of operations for working with sequences of data.

## Features

- Lazy evaluation
- Memory-safe operations
- Rich set of transformation methods
- Composable operations
- Full error handling support

## Installation

Add `iterator.zig` to your project and import it:

```zig
const Iterator = @import("iterator.zig").Iterator;
```

## Quick Start

```zig
const std = @import("std");
const Iterator = @import("iterator.zig").Iterator;

// Create an iterator
var numbers = [_]i32{ 1, 2, 3, 4, 5 };
var iter = Iterator(i32).init(&numbers);

// Basic iteration
while (iter.next()) |num| {
    std.debug.print("{d}\n", .{num});
}
```

## API Reference

### Core Operations

#### `init(items: []const T) Self`
Creates a new iterator from a slice.

```zig
var numbers = [_]i32{ 1, 2, 3 };
var iter = Iterator(i32).init(&numbers);
```

#### `next(self: *Self) ?T`
Returns the next item and advances the iterator.

```zig
while (iter.next()) |item| {
    // Process item
}
```

#### `peek(self: Self) ?T`
Returns the next item without advancing.

```zig
if (iter.peek()) |next_item| {
    // Look at next_item without consuming it
}
```

### Transformations

#### `map(self: *Self, allocator: Allocator, comptime Ret: type, comptime func: fn (T) Ret) !ArrayList(Ret)`
Transforms each element using a function.

```zig
const double = struct {
    fn func(x: i32) i32 {
        return x * 2;
    }
}.func;

var doubled = try iter.map(allocator, i32, double);
defer doubled.deinit();
```

#### `filter(self: *Self, allocator: Allocator, comptime pred: fn (T) bool) !ArrayList(T)`
Keeps only elements that satisfy the predicate.

```zig
const isEven = struct {
    fn func(x: i32) bool {
        return @mod(x, 2) == 0;
    }
}.func;

var evens = try iter.filter(allocator, isEven);
defer evens.deinit();
```

### Aggregations

#### `reduce(self: *Self, comptime Acc: type, initial: Acc, comptime func: fn (Acc, T) Acc) Acc`
Combines all elements into a single value.

```zig
const sum = struct {
    fn func(acc: i32, x: i32) i32 {
        return acc + x;
    }
}.func;

const total = iter.reduce(i32, 0, sum);
```

### Collection Operations

#### `take(self: *Self, allocator: Allocator, n: usize) !ArrayList(T)`
Takes up to n elements.

```zig
var first_three = try iter.take(allocator, 3);
defer first_three.deinit();
```

#### `skip(self: *Self, n: usize) void`
Advances the iterator by n positions.

```zig
iter.skip(2); // Skip first two elements
```

#### `collect(self: *Self, allocator: Allocator) !ArrayList(T)`
Collects all remaining elements.

```zig
var all = try iter.collect(allocator);
defer all.deinit();
```

### Combining Iterators

#### `chain(self: *Self, allocator: Allocator, other: *Self) !ArrayList(T)`
Concatenates two iterators.

```zig
var combined = try iter1.chain(allocator, &iter2);
defer combined.deinit();
```

#### `zip(self: *Self, comptime U: type, allocator: Allocator, other: *Iterator(U)) !ArrayList(ZipResult(U))`
Combines elements from two iterators pairwise.

```zig
var pairs = try iter1.zip(u8, allocator, &iter2);
defer pairs.deinit();
```

### Predicates

#### `any(self: *Self, comptime pred: fn (T) bool) bool`
Returns true if pred returns true for any element.

#### `all(self: *Self, comptime pred: fn (T) bool) bool`
Returns true if pred returns true for all elements.

#### `none(self: *Self, comptime pred: fn (T) bool) bool`
Returns true if pred returns false for all elements.

## Memory Management

All methods that return an ArrayList transfer ownership to the caller. The caller is responsible for calling `deinit()` on these ArrayLists when they're no longer needed.

```zig
var result = try iter.collect(allocator);
defer result.deinit(); // Don't forget this!
```

## Error Handling

Methods that can fail return an error union and should be called with try:

```zig
var result = try iter.map(allocator, i32, double);
```

## Thread Safety

The Iterator type is not thread-safe. Each iterator should be used by a single thread.
