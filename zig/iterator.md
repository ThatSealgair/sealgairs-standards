# Iterator

> A Zig library for iterating over sequences of data with transformation and collection operations.

- Create a new iterator from a slice:
```zig
var numbers = [_]i32{ 1, 2, 3 };
var iter = Iterator(i32).init(&numbers);
```

- Iterate over elements:
```zig
while (iter.next()) |item| {
    // Process item
}
```

- Transform elements with map:
```zig
var doubled = try iter.map(allocator, i32, double_func);
defer doubled.deinit();
```

- Filter elements:
```zig
var filtered = try iter.filter(allocator, predicate_func);
defer filtered.deinit();
```

- Reduce to a single value:
```zig
const total = iter.reduce(i32, 0, sum_func);
```

- Take first n elements:
```zig
var first_n = try iter.take(allocator, n);
defer first_n.deinit();
```

- Skip n elements:
```zig
iter.skip(n);
```

- Combine two iterators:
```zig
var combined = try iter1.chain(allocator, &iter2);
defer combined.deinit();
```

- Zip two iterators:
```zig
var pairs = try iter1.zip(U, allocator, &iter2);
defer pairs.deinit();
```
