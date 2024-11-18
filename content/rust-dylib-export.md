+++
title = "可执行文件与动态库共享全局变量"
template = "page.html"
date = 2024-09-16
[taxonomies]
tags = ["rust", "programming"]
+++

有时候我们会希望通过 dlopen 来加载一个动态链接库，并且在主程序中和库中访问同一个全局变量。下面用 Rust 来实现一个 [MWE]。

[MWE]: https://en.wikipedia.org/wiki/Minimal_reproducible_example

<!-- more -->

<style>
img {
max-width: 400px;
display: block;
margin: auto;
}
</style>


我们首先需要一个 binary 项目（main）和一个 cdylib 项目（liba.so），然后为了使两个项目共享同一个变量，它们依赖同一个 common crate。最终的项目结构如下：

![project structure](project.svg)

这里的 dlopen 使用 [libloading] 库来实现。main 的代码如下：

[libloading]: https://lib.rs/crates/libloading

```rust
use std::sync::atomic::Ordering;

use common::FOO;
use libloading::Library;

fn main() {
    unsafe {
        // Modify FOO in the main binary
        FOO.store(10, Ordering::SeqCst);
        println!(
            "FOO after main modification: {}",
            FOO.load(Ordering::Relaxed)
        );

        // Load and call the function from `liba` to modify FOO
        let lib_b = Library::new("liba.so").unwrap();
        let modify_foo = lib_b.get::<extern "C" fn()>(b"modify_foo\0").unwrap();
        modify_foo();

        println!("FOO after b modification: {}", FOO.load(Ordering::Relaxed));
    }
}
```

运行代码，发现 `modify_foo` 并不起作用，这也就意味着两个项目的 `FOO` 并不是同一个。

```console
$ cargo run
    Finished `dev` profile [unoptimized + debuginfo] target(s) in 0.00s
     Running `target/debug/rust-dylib-export`
FOO after main modification: 10
FOO after b modification: 10
```

通过 `LD_DEBUG` 我们可以看到符号加载的情况

```console
$ LD_DEBUG=symbols cargo run 2>&1 | rg FOO
FOO after main modification: 10
    135603:     symbol=FOO;  lookup in file=target/debug/rust-dylib-export [0]
    135603:     symbol=FOO;  lookup in file=/usr/lib/libgcc_s.so.1 [0]
    135603:     symbol=FOO;  lookup in file=/usr/lib/libc.so.6 [0]
    135603:     symbol=FOO;  lookup in file=/lib64/ld-linux-x86-64.so.2 [0]
    135603:     symbol=FOO;  lookup in file=[...]/target/debug/deps/liba.so [0]
FOO after b modification: 10
```

说明 `FOO` 是在加载 `liba.so` 之后才被加载的。
理想状态下，main 和 liba 中都有一个 `FOO` 符号，这个符号会在 main 加载的时候加载。而 liba 加载时，根据 ELF 的符号抢占机制，liba 的 `FOO` 符号直接被定位到和 main 的 `FOO` 相同的位置。
为什么 main 函数被加载的时候没有加载 `FOO` 符号呢？我首先怀疑是符号的 Visibility 被设置为了 Protected。

检查一下符号：

```console
$ readelf -sWC target/debug/liba.so | rg 'Symbol table|Num:|FOO'
Symbol table '.dynsym' contains 53 entries:
   Num:    Value          Size Type    Bind   Vis      Ndx Name
    52: 000000000004f064     4 OBJECT  GLOBAL DEFAULT   24 FOO
Symbol table '.symtab' contains 639 entries:
   Num:    Value          Size Type    Bind   Vis      Ndx Name
   610: 000000000004f064     4 OBJECT  GLOBAL DEFAULT   24 FOO
$ readelf -sWC target/debug/rust-dylib-export | rg 'Symbol table|Num:|FOO'
Symbol table '.dynsym' contains 71 entries:
   Num:    Value          Size Type    Bind   Vis      Ndx Name
Symbol table '.symtab' contains 936 entries:
   Num:    Value          Size Type    Bind   Vis      Ndx Name
   734: 000000000005d064     4 OBJECT  GLOBAL DEFAULT   28 FOO
```

我们发现 Visibility 并没有问题，问题在于 main 的 `.dynsym` 表中没有 `FOO` 这个符号。这样 main 就无法抢占后面加载模块的 `FOO` 符号。知道了症结，问题就好解决了。容易查到 `ld` 默认不会导出可执行文件的符号到 `.dynsym` 表中，使用参数 `--export-dynamic` 即可以覆盖这一行为。

在 Rust 中有两种方式设置 linker 参数：Cargo config，和 `build.rs`。由于 Cargo config 是项目全局的，这里我们使用 `build.rs` 仅针对 main 项目修改链接参数：

```rust
fn main() {
    println!("cargo:rustc-link-arg=-Wl,--export-dynamic");
}
```

这样我们的程序就可以按预期执行了：

```console
$ cargo run
    Finished `dev` profile [unoptimized + debuginfo] target(s) in 0.00s
     Running `target/debug/rust-dylib-export`
FOO after main modification: 10
FOO after b modification: 1
```
