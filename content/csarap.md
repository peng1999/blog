+++
title = "Computer System: A Rust Programmer's Perspective"
date = 2018-12-29
[taxonomies]
tags = ["programming", "rust"]
+++

Rust 的系统编程。

<!-- more -->

这篇文章可以算是我阅读 CSAPP 的非传统读书笔记。CSAPP 使用了 C 这种与硬件联系特别
紧密的语言作为教学语言，我每读一个章节，就把书中内容用 Rust 重新实现一遍。毕竟 Rust 也是系统级编程
语言，理论上不会有任何问题。

我期望这篇文章可以作为 CSAPP 的补充材料，所以我假设读者已经读过 CSAPP 的相关章节，或具备相应知识，
但不会对读者具备的 Rust 知识做太多假设。本文会把着重点放在 Rust 与 C 不同的地方。

文中会有 `#CSAPP:2.1.1` 的字样，表示对应的 CSAPP 章节。

# 信息的表示与处理

## 数据类型

{{hashtag(tag = "CSAPP:2.1.1")}}

在 Rust 中，[整数](https://doc.rust-lang.org/reference/tokens.html#number-literals)默认是十进制，
以`0x`开头的数字为十六进制，以`0b`开头的数字为二进制。例如，我们可以将 FF7A34B3<sub>16</sub> 写作
`0xFF7A34B3`，或是`0xff7a34b3`；将 01111101<sub>2</sub> 写作`0b0111_1101`。注意下划线可以在
任意两个数位间插入，编译器将忽略它们。

{{hashtag(tag = "CSAPP:2.1.2")}}

Rust 支持多种数值数据格式。它们的字节大小可以用 `std::mem::size_of::<Type>()` 获取。
一般而言，基本数据类型的大小可以直接由类型名看出。另外，当 `T` 的大小确定时，指针
类型 `&T` 和 `usize`、`isize` 的大小相同，都是编译所在平台架构的的指针大小。

{{hashtag(tag = "CSAPP:2.1.4")}}

在字符串的问题上，Rust 始终采用 UTF-8 字符串编码。UTF-8 没有端序的问题，所以一段字符串的
二进制表示总是不变的。

## 寻址和字节顺序

{{hashtag(tag = "CSAPP:2.1.3")}}

下面的代码用于显示数据的字节表示。

``` rust
fn show_bytes<T>(data: &T) {
    let size = std::mem::size_of::<&T>();
    let repr = data as *const T as *const u8;
    for i in 0 .. size {
        unsafe {
            print!("{:02x} ", *repr.offset(i as isize));
        }
    }
    println!("");
}

fn main() {
    let val: i32 = 12345;
    let pval = &val;
    show_bytes(&pval);
}
```

由于 Rust 无法判断指向`data`的指针`repr`经过`offset`偏移之后是否有效，
所以我们需要用`unsafe`显式标记。

在一台 64 位的机器上，程序运行的结果类似于`ec 29 bd 50 fd 7f 00 00 `，
说明该机器采用小端存储方式。

# 程序的机器级表示

{{hashtag(tag = "CSAPP:3")}}

采用下面这条指令可以查看 Rust 编译器生成的汇汇编代码：


```sh
rustc filename.rs --crate-type=lib --emit=asm -C opt-level=3
```

# 代码优化

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
