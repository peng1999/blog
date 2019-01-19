+++
title = "目录 - Computer System: A Rust Programmer's Perspective"
date = 2018-12-29
[taxonomies]
tags = ["programming", "rust"]
+++

Rust 的系统编程。

<!-- more -->

NPU 的培养计划建议把 ICS[^ics] 课程放到大一上，于是我有机会趁机阅读 CSAPP[^csapp] 的一些章节。
这个系列可以算是我的一个非传统读书笔记。

CSAPP 使用了 C 这种与硬件联系特别紧密的语言作为教学语言，而 Rust 同是系统级编程语言，
与 C 的一些关于计算机系统底层的对比会是一件很有意思的事。
同时我会探究书中的知识在 Rust 上的体现。

我期望这篇文章可以作为 CSAPP 的补充材料，所以我假设读者已经读过 CSAPP 的相关章节，或具备相应知识，
但不会对读者具备的 Rust 知识做太多假设。<!-- 本文会把着重点放在 Rust 与 C 不同的地方。 -->

文中会有 `#CSAPP:2.1.1` 的字样，表示对应的 CSAPP 章节。

## 系列目录

- [信息的表示与处理](./csarap-data.md)
- [编译器优化](./csarap-opt.md)

---

# Footnote
[^ics]:
计算机系统基础（ **I**ntoduction to **C**omputer **S**ystem）

[^csapp]:
深入理解计算机系统，机械工业出版社，英文名为 *Computer System: A Programmer's Perspective*。

