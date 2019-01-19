+++
title = "编译器优化 - CSARPP"
date = 2019-01-19
[taxonomies]
tags = ["programming", "rust"]
+++

# 程序的机器级表示

{{hashtag(tag = "CSAPP:3")}}

采用下面这条指令可以查看 Rust 编译器生成的汇汇编代码：


```sh
rustc filename.rs --crate-type=lib --emit=asm -C opt-level=3
```

# 编译器优化

{{hashtag(tag = "CSAPP:5")}}

## 优化的阻碍
### Alias 优化

在 Rust 中，一个可变的引用（`&mut T`）不会存在别名。这使得 Rust 编译器可以告诉 LLVM 后端
某个指针不存在别名（noalias）。这可以开启一些 C 语言中不存在的优化。例如下面的代码：

```rust
pub fn func(a: &mut i64, b: &mut i64) {
    *a += *b;
    *a += *b;
}
```

将会产生下面的输出：

```asm
ZN1a3add17h058f239ac4f807c2E:
    movq    (%rsi), %rax
    addq    %rax, %rax
    addq    %rax, (%rdi)
    retq
```

这相当于

```rust
pub fn func(a: &mut i64, b: &mut i64) {
    *a += 2 * *b;
}
```

注意到当 `a` 与 `b` 相同时，这样的优化是不成立的，但是 Rust 可以保证 `a != b`，所以
Rust 可以做这种优化，而 C 则不行。[^noalias]


---

# Footnote

[^noalias]:
可惜的是，由于 LLVM 的一些 Bug，目前在 rustc 1.33.0-nightly (790f4c566 2018-12-19) 下，
这个优化被[默认关闭了][noalias-defaut-no]。需要使用 `-Z mutable-noalias` 开启这个优化。
一旦 LLVM 的 Bug 被修复，这个优化将重新被默认开启，相关的 Tracking issue
在[这里](https://github.com/rust-lang/rust/issues/54878)。

[noalias-defaut-no]: https://github.com/rust-lang/rust/pull/54639
