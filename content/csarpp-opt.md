+++
title = "编译器优化 - CSARPP"
date = 2019-01-19
[taxonomies]
tags = ["programming", "rust"]
+++

# 程序的机器级表示

{{hashtag(tag = "CSAPP:3")}}

采用下面这条指令可以查看 Rust 编译器生成的汇编代码：


```sh
rustc filename.rs --crate-type=lib --emit=asm -C opt-level=2
```
其中 `--crate-type=lib` 是为了以库的方式编译，避免出现“`main` 未定义”的错误。
`opt-level` 设置编译级别。由于 Rust 具有较多的抽象层，至少要开级别 2 的优化，
编译器才会将诸如 `into_iter` 这样的函数调用优化掉，我们才能看到比较清晰的汇编代码。

# 编译器优化

{{hashtag(tag = "CSAPP:5")}}

## 优化的阻碍
### 指针别名

在 Rust 中，一个可变的引用（`&mut T`）不会存在别名。这使得 Rust 编译器可以告诉 LLVM 后端
某个指针不存在别名（noalias）。这可以开启一些 C 语言中不可行的优化。例如下面的代码：

```rust
pub fn add(a: &mut i64, b: &mut i64) {
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
pub fn add2(a: &mut i64, b: &mut i64) {
    *a += 2 * *b;
}
```

注意到如果 `a` 与 `b` 能够指向相同的变量 `c` \\(=x\\)，那么 `add(a, b)` 使 `c` 变为 \\(4x\\)，
`add2(a, b)` 使 `c` 变为 \\(2x\\)，那么这个优化就不成立了。但是 Rust 可以保证
可变引用是独占的，即 `a != b`，所以 Rust 可以做这种优化。[^noalias]

## 不必要的内存引用

对于 CPU 而言，访问内存显然比访问寄存器更慢。考虑下面的 C 语言循环：

```c
typedef struct {
    long len;
    double *data;
} vec_rec, *vec_ptr;

void combine3(vec_ptr v, double *dest) {
    long length = v->len;
    double *data = v->data;

    *dest = 0;
    for (long i = 0; i < length; i++) {
        *dest += data[i];
    }
}
```

这将造成在循环中，`dest` 所指向的内存被频繁访问。然而由于前述指针别名的
问题，编译器无法对此做优化。在 Rust 中，同样功能的代码

```rust
pub fn combine1(vec: &Vec<Data>, dest: &mut Data) {
    *dest = 0;
    for a in vec {
        *dest += a;
    }
}
```

循环部分编译为如下汇编（优化级别 2）：

```asm
; dest in %rsi
.LBB1_8:
	addsd	(%rax), %xmm0
	addsd	8(%rax), %xmm0
	addsd	16(%rax), %xmm0
	addsd	24(%rax), %xmm0
	addsd	32(%rax), %xmm0
	addsd	40(%rax), %xmm0
	addsd	48(%rax), %xmm0
	addsd	56(%rax), %xmm0
	addq	$64, %rax
	cmpq	%rcx, %rax
	jne	.LBB1_8
.LBB1_9:
	movsd	%xmm0, (%rsi)   ; write %xmm0 to *dest
	retq

```
可以看到所求值被累加进了 `%xmm0` 寄存器，最后才被写入 `%rsi` 指向的内存。
这样就获得了更佳的性能。[^expand]

我同时注意到，将 `*dest += a` 换为 `*dest = *dest + a` 后，编译器就不能做
这个优化了。可见复合赋值语句不仅能让我们少打几个字符，还能帮助编译器优化。

---

# Footnote

[^noalias]:
可惜的是，由于 LLVM 的一些 Bug，目前在 rustc 1.33.0-nightly (790f4c566 2018-12-19) 下，
这个优化被[默认关闭了][noalias-defaut-no]。需要使用 `rustc` 的 `-Z mutable-noalias`
选项开启这个优化。 一旦 LLVM 的 Bug 被修复，这个优化将重新被默认开启，相关的 Tracking issue
在[这里](https://github.com/rust-lang/rust/issues/54878)。

[noalias-defaut-no]: https://github.com/rust-lang/rust/pull/54639

[^expand]:
之所以有 8 条 `addsd` 指令，是因为编译器做了循环展开优化。
