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

---

# Footnote
