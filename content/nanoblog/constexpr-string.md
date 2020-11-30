+++
title = "constexpr string"
template = "page.html"
date = 2019-12-19
[taxonomies]
tags = ["programming", "cpp"]
+++

按照 [Andrzej's C++ blog] 里这篇文章的思路，我实现了一个编译期的字符串拼接：

```c++
template<int N>
class sstring {
    char inner[N];

    constexpr sstring() = default;

public:
    constexpr sstring(const char (&s)[N]) : inner{} {
        for (int i = 0; i < N; ++i) {
            inner[i] = s[i];
        }
    }

    template<int M>
    constexpr sstring(const sstring<M> &lhs, const sstring<N - M> &rhs) : inner{} {
        for (int i = 0; i < M; ++i) {
            inner[i] = lhs[i];
        }
        for (int i = 0; i < N - M; ++i) {
            inner[i + N] = rhs[i];
        }
    }

    constexpr char operator[](int i) const {
        return inner[i];
    }
};

template<int N>
sstring(char (&s)[N]) -> sstring<N>;

template<int M, int N>
sstring(const sstring<M> &lhs, const sstring<N> &rhs) -> sstring<N + M>;

template<int M, int N>
constexpr auto operator+(const sstring<M> &lhs, const sstring<N> &rhs) {
    return sstring(lhs, rhs);
}

constexpr sstring s {"123"};
constexpr sstring q {"456"};
constexpr sstring r {s + q};
```

- `constexpr string` 有什么用？这至少在初始化全局静态变量时有用。`constexpr` 静态变量不会存在烦人的初始化顺序问题。
- 因为用到了 deducing guide，所以至少需要在 C++ 17 下编译。
- `std::string` 将在 C++ 20 支持 `constexpr`，不过编译器全部普及这个特性可能还要等好几年。
    - C++ 现在有一种「`constexpr` Everything」的倾向。这是为了更好的实现元编程。这是好事。
- `constexpr` 构造函数要求初始化每个每个子对象和非静态数据成员必须被初始化。奇怪的是，clang 可以通过未初始化的代码。

[Andrzej's C++ blog]: https://akrzemi1.wordpress.com/2017/06/28/compile-time-string-concatenation/

