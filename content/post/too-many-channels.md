+++
title = "Too many channels in Rust but only one in Go"
date = 2022-03-24
tags = ["programming", "go", "rust"]
+++

Channel 是异步编程 CSP 模型[^csp]和 Actor 模型的重要组成部分，是一种用于消息同步的数据结构。Go 语言中的 `chan` 类型即是一种 channel 的实现。在使用 Rust 进行异步编程的时候也需要使用 channel。然而 Rust 中的 channel 似乎太多了。

<!--more-->

<style type="text/css">
em, strong {
color: purple;
}
img {
display: block;
margin: 0 auto;
}
</style>

首先 Rust 标准库 `std::sync::mpsc` 模块中就提供了两种 channel 实现 `channel` 和 `sync_channel`。最流行的 Rust 异步运行时 [tokio] 也在 `tokio::sync` 模块中提供了其自己的 channel 实现，有四种之多。如果我们访问 Lib.rs 上的 [Concurrency] 分类，我们能轻易找到排名第 2 和第 8 的两个专门的 channel 库 crossbeam-channel 和 flume。这两个库分别有上千和上百的公开 crate 依赖。既然在 Go 语言当中，一种 channel 就够了，那在 Rust 中我们为什么需要这么多 channel 呢？

[tokio]: https://tokio.rs
[Concurrency]: https://lib.rs/concurrency

## Go and rendezvous

实际上，channel 不止一种。Go 语言里使用 `make(chan T)` 创建的是 *rendezvous channel*，内部不使用缓冲区。如果通过一个 rendezvous channel 从一个 goroutine 向另一个 goroutine 发送消息，则会一直阻塞，直到对方接收为止。如果我们希望发送数据的 goroutine 不要阻塞，那么可以使用 `make(chan T, size)` 创建一个 *buffered channel*，这时将会创建一个大小为 `size` 的缓冲区。只要缓冲区不满，发送者就不必阻塞。

[chanx]: https://github.com/smallnest/chanx

在 Go 语言中，并不需要有意避免阻塞一个 goroutine，调度器将会把当前的 CPU 资源分给其他可以继续执行的 goroutine。所以大多数时候简单的 rendezvous channel 就足够用了。但是如果由于种种原因，我们真的需要 channel 永远不要阻塞，这时即使是固定大小的 buffered channel 也不能满足要求，我们需要一个能自动扩容缓冲区的 *unbounded buffered channel*。Go 内置的 `chan` 类型没有提供这样的功能，好在我们可以将两个 renderzvous channel 和一个可扩容的环状缓冲区组合起来，实现一个 unbounded buffer。[chanx] 就是这样的一个实现[^chanx]。

![rendezvous](rendezvous.drawio.svg)

查看 chanx 的源代码我们可以看到，其内部使用了两个 `chan`，并为每个 channel 都创建了一个新的 goroutine。这显然带来了不必要的开销。用一种 channel 来实现其他类型的 channel，这当然符合 Go 语言极简主义的哲学，然而其付出的性能代价是 Rust 所不能接受的。所以我们看到 Rust 标准库除了提供类似于 Go `chan` 的 `mpsc::sync_channel`，还另外实现了 unbounded channel 即 `mpsc::channel`。其他 Rust 库的 channel 也基本都提供了 bounded 和 unbounded 变体。

值得注意的是在 Go 语言当中 rendezvous channel 常常和 select 语句搭配使用，而 Rust 标准库中的 `select!` 宏由于种种原因已经[被移除了][std-select]。好在第三方库的 channel 都实现了 `select!` 宏，想要在 Rust 中像 Go 一样用 rendezvous channel 和 select 编写程序的话，使用第三方库即可。

[std-select]: https://github.com/rust-lang/rust/pull/60921

## Can the sender awaits?

缓冲区的问题归根结底还是发送端 send 函数阻塞的问题。基本上我们有「unbounded channel —— 不阻塞线程；bounded channel —— 可能阻塞线程」这样一组对应关系。为了像 Go 语言一样即使没有缓冲区也不阻塞线程，我们需要利用 Rust 的 async 机制。支持 async 异步的 channel 将包含一个 `async fn send(T)` 和 `async fn recv()`，调用时只会阻塞当前 task 而不会影响其他任务。

与 Go 语言不同，Rust 的 async 函数是所谓的「着色函数」，这意味这不能在非 async 环境中调用 async 函数。同时，基于 async 运行时的实现原理，也不能在 async 环境中直接调用同步的阻塞函数。这样实际上可以把函数分成三种类型：非阻塞函数（unblocked）、同步的阻塞函数（blocked）、以及 async 函数。他们的特性可以总结如下：

| | 可以用在非 asnyc 环境 | 可以用在 async 环境 |
|--|--|--|
| 不会阻塞 | unblocked | unblocked |
| 可能阻塞 | blocked | async |

不同的 channel 实现，其 `send` 和 `recv` 函数具有的阻塞性质可能会不同。我们需要根据需求选取。如果 channel 一边实现了 async 函数，另一边实现了非 async 函数，我们就可以利用该 channel 在没有锁的情况下实现 async 程序部分与非 async 部分的同步。

## To be cloneable or not to be cloneable

一个典型的 Rust channel 会被这样创建：

```rust
let (tx, rx): (Sender, Receiver) = channel();
```

Sender 和 Receiver 在同一个线程被分别创建，然后再发到各自的线程执行工作。Rust 在语言层面上保证了多线程安全，在其中遇见多线程环境下使用的类型，自然会想要考察这两个对象相关的特性：

1. 它是否可以穿过线程边界？
2. 它是否能够被多个线程无锁地共享？
3. 它是否可以被低代价地克隆？

对于第 1 个问题，简单地检查类型是否满足 [`Send`] 约束即可。答案显然是肯定的。作为 Rust 多线程安全的基石之一，绝大多数类型都实现了 `Send`。各 channel 库中的 Sender 和 Receiver 也不例外。[^mutex-sync]

[`Send`]: https://doc.rust-lang.org/std/marker/trait.Send.html

而第 2 个问题则没有看起来的那么简单。虽然 Rust 中有 `Sync` 这个 trait，而且和 `Send` 一样，绝大多数类型也实现了 `Sync`，但是 `T: Sync` 只意味着**不可变**的 `&T` 能被多个线程共享。如果某个 Sender 的 send 函数或 Receiver 的 recv 函数要求拿到一个 `&mut self`，仅仅**不可变**的共享则完全没有意义。所以，要想肯定地回答问题 2，需要同时满足两个条件：所考察对象满足 `Sync` 约束；其 send / recv 函数只要求不可变的 `&self` 引用。`std::sync::mpsc::Receiver` 即不满足前一个条件，而 `tokio::sync::mpsc::Receiver` 则不满足后一个条件。

即使对象能够以 `&T` 的形式在多个线程中无锁共享，在多数情况下，为了解决生命周期的问题，我们仍然需要在外面套上 `Arc` 才能达到目的。

```rust
let (tx, rx) = channel();
let tx_arc = Arc::new(tx);
let tx_clone = tx_arc.clone();
std::process::spawn(|| tx_clone.send(something()));
```

这时自然会想到，如果 `tx` 自身能够 `clone`，那么我们就不必再套一个 `Arc` 了。这正是我们要考察的第 3 个特性。如果 Sender 实现了 `Clone` 约束，我们可以直接通过克隆来在多个线程之间分享：

```rust
let (tx, rx) = channel();
let tx_clone = tx.clone();
std::process::spawn(|| tx_clone.send(something()));
```

虽然性质 2 和性质 3 并不全等，然而实现了性质 2 的 channel 类型实际上也都实现了性质 3。一般而言，在考察 channel 类型的线程同步特性时，只需要考察它是否实现 `Clone` 即可。

回过头来考察 Go 语言的 channel，我们发现其 `chan` 类型既可以做 Sender，也可以做 Receiver。`chan` 也可以安全地被克隆，在多个线程中共享。这实际上一个 MPMC channel[^mpmc]。而在 Rust 中，通过限制 `Receiver: !Clone`，我们可以得到一个 MPSC channel。注意虽然 MPMC channel 有多个出口，但任意的消息只能从其中一个出口出去。如果我们需要一个「广播」性质的 channel，我们可以实现一个 MPSC channel 数组，每个消息分别向各个出口发送，也可以直接使用 `tokio::sync::broadcast` 中的 channel。

![broadcast](broadcast.drawio.svg)

## Mix all together

前面讨论了缓冲区大小、`send` / `recv` 函数的阻塞性、以及 `Clone` trait。在不同的场合下，我们需要选取具有不同特性组合的 channel。现在是时候画一张大表把它们全部列出来了。

<table>
<thead>
  <tr>
    <th colspan="2"> Channel constructor </th>
    <th>Buffer size </th>
    <th>Cloneable </th>
    <th>send </th>
    <th>recv </th>
  </tr>
</thead>
<tbody>
  <tr>
    <td rowspan="2">std::mpsc <br> </td>
    <td>channel </td>
    <td>∞ </td>
    <td>Sender </td>
    <td>unblocked </td>
    <td>blocked </td>
  </tr>
  <tr>
    <td>sync_channel </td>
    <td>0~n </td>
    <td>Sender </td>
    <td>blocked </td>
    <td>blocked </td>
  </tr>
  <tr>
    <td rowspan="2">crossbeam-channel <br> </td>
    <td>unbounded <br> </td>
    <td>∞ <br> </td>
    <td>Sender, Receiver <br> </td>
    <td>unblocked <br> </td>
    <td>blocked </td>
  </tr>
  <tr>
    <td>bounded </td>
    <td>0~n </td>
    <td>Sender, Receiver </td>
    <td>blocked </td>
    <td>blocked </td>
  </tr>
  <tr>
    <td rowspan="3">tokio::sync <br> </td>
    <td>mpsc::unbounded_channel </td>
    <td>∞ <br> </td>
    <td>Sender </td>
    <td>unblocked </td>
    <td>async </td>
  </tr>
  <tr>
    <td>mpsc::channel </td>
    <td>1~n </td>
    <td>Sender </td>
    <td>async </td>
    <td>async </td>
  </tr>
  <tr>
    <td>broadcast </td>
    <td>1~n </td>
    <td>Sender </td>
    <td>unblocked </td>
    <td>async </td>
  </tr>
  <tr>
    <td rowspan="2">flume </td>
    <td>unbounded <br> </td>
    <td>∞ <br> </td>
    <td>Sender, Receiver <br> </td>
    <td>unblocked <br> </td>
    <td>blocked/async </td>
  </tr>
  <tr>
    <td>bounded </td>
    <td>0~n </td>
    <td>Sender, Receiver </td>
    <td>blocked/async </td>
    <td>blocked/async </td>
  </tr>
</tbody>
</table>

`recv` 不可能做到完全不阻塞，但是 Receiver 一般都提供一个不阻塞的 `try_recv` 函数。

`tokio::sync::broadcast` 里的 Receiver 虽然不能 clone，但是可以直接通过 `Sender::subscribe` 得到。

## Epilogue

本文所讨论的 channel 概念源自异步编程模型 CSP 和 Actor，这两种模型都是语言无关的数学抽象。我们看到同样的概念可以同时用在不同的语言之中。在这样的基础上，Go 语言中基于 CSP 的异步编程模型可以直接迁移到 Rust 当中去。虽然这两种语言各自具有鲜明的特点，Go 语言奉行极简主义，而 Rust 则拥抱复杂性以换取安全和更好的性能，但一个熟悉 Go 异步编程的程序员，应当发现能用同样的心智模型在 Rust 编写异步程序。

## Footnotes

[^csp]: Communicating Sequential Processes，交谈循序程序，又译为通信顺序进程、交换消息的循序程序

[^chanx]: 实际上 chanx 使用了一定大小的 channel buffer，不过如果移除这个 buffer，程序仍然能正常工作。

[^mutex-sync]: `T: !Send` 的类型在多线程环境中寸步难行。注意到 `std::sync::Mutex` 的 [`Send` 和 `Sync` 实现](https://doc.rust-lang.org/std/sync/struct.Mutex.html#impl-Send)：
  ```rust
  impl<T: ?Sized + Send> Send for Mutex<T> {}
  impl<T: ?Sized + Send> Sync for Mutex<T> {}
  ```
  如果一个类型 `T: !Send`，我们甚至没法通过加锁实现跨线程共享。

[^mpmc]: Multiple producer multiple consumer.
