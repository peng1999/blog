+++
title = "Rust 和 C++ 的对象生命管理"
template = "page.html"
date = 2023-11-14
[taxonomies]
tags = ["rust", "cpp", "programming"]
+++

Rust 和 C++ 的对象都是值语义，都采用了 RAII 惯用法。所以他们需要处理类似的对象生命周期问题：需要专门的代码来处理对象的初始化，复制和析构。下面进行一个比较，我们能够看到两种语言之间内在的对称性。

<!-- more -->

# 普通构造

每个对象都需要一个初始化过程，但 Rust 没有构造函数的概念。没有类继承概念的 Rust 可以利用 **struct 表达式**初始化每个对象。这类似于 C++ **聚合初始化**。

Rust:
```rust
struct S { a: i32, b: i32 }

let s = S { a: 1, b: 2 };
```

C++:
```c++
struct S { int32_t a; int32_t b; };

auto s = S { .a = 1, .b = 2 };
```
而其他形式的初始化封装就由函数来解决，而不是像 C++ 专门引入了构造函数的概念。

Rust:
```rust
impl S {
  fn new(a: i32) -> S {
    println!("Do other thing!")
    S { a, b: a + 1 }
  }
}
```
C++:
```c++
struct S {
  // ...
  S(int32_t a) : a{a}, b{a + 1} {
    std::println("Do other thing!");
  }
}
```

C++ 可以生成默认构造函数 `T::T()`。Rust 可以生成普通函数 `fn Default::default() -> T`。

Rust:
```rust
#[derive(Default)]
struct S { /*...*/ }

let s = S::default();
```
C++:
```c++
struct S {
  S() = default;
};

auto s = S{};
```

# 复制构造

Rust 的非 POD 对象默认不能复制。实现了 `Clone` trait 的对象就能复制了。当然 `Clone` 可以默认生成。

Rust:
```rust
#[derive(Clone)]
struct S {}

let s1 = S::new();
s1.clone(); // copy to a temporary
```
C++:
```c++
struct S {
   S(const S&) = default;
};

auto s1 = S{};
auto s2 = s1; // no temporary, only s1 and s2
```

# 移动构造

注意到上面例子细微的对称性破缺：在 C++ 中，`auto s2 = s1;` 是单条初始化语句，而在 Rust 中，`let s2 = s1.clone()` 涉及到了两个操作：`s1.clone()` 复制了 `s1`，并返回了一个临时对象；临时对象被移动进 s2 中完成初始化。所以在上面的 Rust 例子中我只写了单个 `s1.clone()` 表达式。

这里涉及到 Rust 移动语义与 C++ 最大的不同：**Rust 中所有对象都可移动，移动总是高效的，移动不会发生任何可观测的副作用。** Rust 的移动操作是默认发生的，总是可以被理解为对象的按字节浅复制。（没错，Rust 中的移动*在语义上*实际上是复制）

而 C++ 的移动，套用 *Effective Modern C++, Item 29* 的话来说：**移动操作可能不存在，成本高，或未被使用。**

之所以会是如此，是因为 C++ 中对象被移动后仍然可用，仍然会被调用构造函数。在 C++ 中，而 Rust 则没有这个问题。 @kulx 老师在上篇帖子中已经阐述了这一点。

这两个语言的移动区别如此之大，以至于本节无法给出有意义的代码对比。

# 赋值操作符
Rust 的赋值操作符总是移动。神奇的是，C++ 中其实有类似的对应物，那就是 by-value assignment operator。请看：
```c++
struct S {
  // constructors...
  void operator=(S rhs) { // by value
    auto member = std::move(rhs.member);
    swap(tmp, *this);
  }
}

S a, b;
a = b; // stmt1
a = std::move(b); // stmt2
```
这里返回值为 `void` 是为了和 Rust 保持对称。这里使用 copy-and-swap 的 C++ 技巧，将赋值运算符巧妙地转发到了构造函数。`swap` 一般就是简单的浅复制就可以实现，我们忽略不计。现在看看 stmt1 发生的复制和移动：

- b -> rhs，一次复制
- rhs -> tmp，一次移动

而 stmt2：

- b -> rhs，rhs -> tmp，两次移动

而对应的 Rust 代码：
```rust
a = b.clone(); // stmt1
a = b; // stmt2
```
stmt1 发生了一次复制和一次移动，stmt2 发生一次移动。我们可以看到对于复制操作，两种语言所具有的对称性。Rust 正是使用这种机制为所有对象实现了默认且不可重载的赋值操作。

# 析构函数

这一段比较平凡。用户可以提供自己的析构函数，也可以用默认的。直接看代码：

Rust:
```rust
impl Drop for S {
  fn drop(&mut self) {
    println!("Doing something");
  }
}
```
C++:
```c++
struct S {
  // ...
  ~S() {
    std::println("Doing something");
  }
}
```

# 总结

总的看来，Rust 在没有历史包袱的情况下，得以采取更加简单的机制组合策略来实现同样的功能。而 C++ 则倾向于提供更高的定制性。下面是一个简单的对照表：

| C++ | Rust |
|---|---|
| 构造函数 | 普通函数 |
| 默认构造 | `Default` |
| 复制构造 | `Clone` |
| 移动构造 | 默认机制 |
| 赋值操作符 | 默认机制 |
| 析构 | `Drop` |
