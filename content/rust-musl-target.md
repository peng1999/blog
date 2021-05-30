+++
title = "Rust 编译到 musl target 的踩坑记录"
date = 2021-05-30
[taxonomies]
tags = ["programming", "rust"]
+++

Rust 在 x86_64-unknown-linux-gnu 目标下默认会动态链接到系统 C 运行时[^linkage]，而不同发行版之间的 libc 可能会有兼容性问题。如果想要把一次编译好的可执行文件放到不同的 Linux 发行版上面去跑，最好采用 x86_64-unknown-linux-musl 目标进行静态编译。

<!-- more -->

> 本文使用的 Rust 版本为 1.54.0-nightly (5dc8789e3 2021-05-21)。

静态编译到 musl 的难度取决于程序是否依赖 C/C++。一般来说[纯 Rust 项目 &lt; 只依赖 C 的项目 &lt; 依赖 C++ 的项目](hard)。
[cross](cross) 提供了方便的基于容器的 Rust 交叉编译工具，但是在 musl 下却[不支持 C++](cross-cxx)。
而我之前在项目中用到的[grpc-rs](grpc-rs)不幸依赖了 C++ 库。有没有更方便的方法编译到 musl 呢？

## Zig Makes Rust Cross-compilation Just Work[^just-work]

[Zig](zig) 是一门尚未到达 1.0 的新语言，但是其开发者在交叉编译领域已经投入了非常多的精力。结果就是 Zig 在 12MiB 的安装包里面带了 47 个 target 的工具链，并且自带了 C/C++ 编译器。只需要安装好 Zig，就能极大简化 musl 编译。

## 设置 Zig wrapper

首先安装 Zig，然后在项目里面创建两个文件 `musl-zcc` 和 `musl-zcxx`：

```sh
$ cat musl-zcc
#!/bin/sh
zig cc -target x86_64-linux-musl $@

$ cat musl-zcxx
#!/bin/sh
zig c++ -target x86_64-linux-musl $@
```

使用 `rustup target add x86_64-unknown-linux-musl` 添加 Rust 的 musl 工具链，然后进行编译：

```sh
CC=$PWD/musl-zcc CXX=$PWD/musl-zcxx cargo build --target x86_64-unknown-linux-musl
```

然后报错了：

```
   Compiling grpcio-sys v0.9.0+1.38.0
error: failed to run custom build command for `grpcio-sys v0.9.0+1.38.0`
[...]
  -- The ASM compiler identification is unknown
  -- Found assembler: [...]/musl-zcc
  -- Warning: Did not find file Compiler/-ASM
[...]
  zig: error: unsupported argument '-g' to option 'Wa,'
[...]
  make: *** [crypto] Error 2
  thread 'main' panicked at
  command did not execute successfully, got: exit status: 2
```

原来是 CMake 没有识别汇编编译器，结果传了一个无效的参数进去。这个参数 GCC 应该是支持的，但是 Clang 则不支持。（Zig 兼容 Clang 的参数）应该是 CMake 版本太老了，从 CMake 3.10 升级到 3.20 就解决了这个问题。

## 设置 Zig 为链接器

我们现在已经能成功编译 `grpcio-sys` 了。但是光能编译还不够，链接仍然会报错，我们需要指定 Zig 为链接器。
创建 `.cargo/config.toml` 文件再进行编译：

```sh
$ cat .cargo/config.toml
[target."x86_64-unknown-linux-musl"]
linker = "./musl-zcxx"
```

⋯⋯然后又报错了。

```
[...]
ld.lld: error: duplicate symbol: _start
>>> defined at crt1.c
>>>            /home/user/.cache/zig/o/7206d15b47617c14656a831114cf92e7/crt1.o:(.text+0x0)
>>> defined at rcrt1.c
>>>            /home/user/.rustup/toolchains/nightly-x86_64-unknown-linux-gnu/lib/rustlib/x86_64-unknown-linux-musl/lib/self-contained/rcrt1.o:(.text+0x0)
[...]
```

怎么同时链接了 Rust 自带的 crt 和 Zig 中的 crt 啊。尝试让 `zig cc` 不要链接 `crt1.o`，试了半天没有成功。
最后发现 Rust 有一个参数可以禁用自带的 crt，于是修改 `.cargo/config.toml`：

```sh
$ cat .cargo/config.toml
[target."x86_64-unknown-linux-musl"]
rustflags = ["-C", "linker-flavor=gcc", "-C", "link-self-contained=no"]
linker = "./musl-zcxx"
```

如此终于能够编译成功。

```
$ file target/x86_64-unknown-linux-musl/debug/xxx
target/x86_64-unknown-linux-musl/debug/xxx: ELF 64-bit LSB executable, x86-64, version 1 (SYSV), statically linked, with debug_info, not stripped

$ ldd target/x86_64-unknown-linux-musl/debug/xxx
        not a dynamic executable
```

---

# Footnote

[^linkage]:
参见 [Rust Reference](https://doc.rust-lang.org/reference/linkage.html)

[hard]: https://zhuanlan.zhihu.com/p/38948830
[cross]: https://github.com/rust-embedded/cross
[cross-cxx]: https://github.com/rust-embedded/cross/issues/101

[^just-work]:
来自博客 https://actually.fyi/posts/zig-makes-rust-cross-compilation-just-work/

[zig]: https://ziglang.org/
