+++
title = "C++ 每三年才解决一点点问题"
template = "page.html"
date = 2020-11-30
[taxonomies]
tags = ["programming", "cpp"]
+++

或：怎样优雅地给 C++ 模板添加约束？

<!-- more -->

我们有一个基类 `Base`，一个子类 `Derived: public Base`，和一个无关的类 `Other`。我们希望实现一个类模版 `M<T>`，只能接受该类的派生类作为类型参数，即 `M<Derived>` 可以编译通过，而 `M<Other>` 则拒绝编译。应该怎么办？

> 以下代码皆依赖头文件 `<type_traits>`

## 实现
### C++ 98

必须从头开始造轮子。此处略。

### C++ 11

```c++
template<typename T,
         typename =
            typename std::enable_if<std::is_base_of<Base, T>::value>::type>
struct C {};
```

### C++ 14

C++14 支持 `std::enable_if_t` 了，这下代码变短了一点。

```c++
template<typename T,
         typename = std::enable_if_t<std::is_base_of<Base, T>::value>>
struct B {};
```

### C++ 17

借助 `std::is_base_of_v`，我们终于可以在 80 个字符的宽度限制下把 `template` 声明写在一行里了。

```c++
template<typename T, typename = std::enable_if_t<std::is_base_of_v<Base, T>>>
struct C {};
```

### C++ 20

2020年3月24日 Clang 10.0 发布。终于我们有了全功能的 Concept。[^1] 随后 GCC 10.0 也支持了 Concept。

```c++
template<typename T> requires std::is_base_of_v<Base, T>
struct D {};
```

目前所有 C++ 编译器中只有 GCC 实现了 `<concept>` 头文件，在 GCC 10.0 中代码可以更加简化：

```c++
template<std::derived_from<Base> T>
struct E {};
```

## 错误信息

### C++ 11

<details>
<summary>GCC Output</summary>

```console
❯ g++ -c a.cpp -std=c++2a
a.cpp: 在函数‘int main()’中:
a.cpp:36:12: 错误：no type named ‘type’ in ‘struct std::enable_if<false, void>’
   36 |     A<Other> d1;
      |            ^
a.cpp:36:12: 错误：模板第 2 个参数无效
```

</details>

嗯？完全让人摸不着头脑的错误信息。用 Clang 试一试：

<details>
<summary>Clang Output</summary>

```console
❯ clang++ a.cpp -std=c++2a
a.cpp:11:57: error: failed requirement 'std::is_base_of<Base, Other>::value'; 'enable_if' cannot be used to disable this declaration
template<typename T, typename = typename std::enable_if<std::is_base_of<Base, T>::value>::type>
                                                        ^~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
a.cpp:36:5: note: in instantiation of default argument for 'A<Other>' required here
    A<Other> d1;
    ^~~~~~~~
1 error generated.
```

</details>

哦，这下看出来了，是 `std::is_base_of<Base, Other>::value` 不满足。

### C++ 14

<details>
<summary>GCC Output</summary>

```console
❯ g++ -c a.cpp -std=c++2a
In file included from a.cpp:1:
/usr/include/c++/10.2.0/type_traits: In substitution of ‘template<bool _Cond, class _Tp> using enable_if_t = typename std::enable_if::type [with bool _Cond = false; _Tp = void]’:
a.cpp:36:12:   required from here
/usr/include/c++/10.2.0/type_traits:2554:11: 错误：no type named ‘type’ in ‘struct std::enable_if<false, void>’
 2554 |     using enable_if_t = typename enable_if<_Cond, _Tp>::type;
      |           ^~~~~~~~~~~
a.cpp: 在函数‘int main()’中:
a.cpp:36:12: 错误：模板第 2 个参数无效
   36 |     B<Other> d1;
      |            ^
```

</details>

`std::is_base_of` 还是被 GCC 吞了。同时 Clang 的错误信息也变糟糕了：

<details>
<summary>Clang Output</summary>

```console
❯ clang++ a.cpp -std=c++2a
In file included from a.cpp:1:
/bin/../lib64/gcc/x86_64-pc-linux-gnu/10.2.0/../../../../include/c++/10.2.0/type_traits:2554:44: error: no type named 'type' in 'std::enable_if<false, void>'; 'enable_if' cannot be used to disable this declaration
    using enable_if_t = typename enable_if<_Cond, _Tp>::type;
                                           ^~~~~
a.cpp:15:38: note: in instantiation of template type alias 'enable_if_t' requested here
template<typename T, typename = std::enable_if_t<std::is_base_of<Base, T>::value>>
                                     ^
a.cpp:36:5: note: in instantiation of default argument for 'B<Other>' required here
    B<Other> d1;
    ^~~~~~~~
1 error generated.
```

</details>

### C++ 17

错误信息相较 C++ 14 的写法没有任何改进。换句话说，如果你在用 C++ 14 或 C++ 17 的写法，你现在能取得的最好的结果是，编译器告诉你，有一个
`std::is_base_of_v<Base, T>` 无法满足约束。至于这个 `T` 是什么，自己猜去吧。

### C++ 20

错误信息：

<details>
<summary>GCC Output</summary>

```console
❯ g++ -c a.cpp -std=c++2a
a.cpp: 在函数‘int main()’中:
a.cpp:36:12: 错误：template constraint failure for ‘template<class T>  requires  is_base_of_v<Base, T> struct D’
   36 |     D<Other> d1;
      |            ^
a.cpp:36:12: 附注：constraints not satisfied
a.cpp:24:8:   required by the constraints of ‘template<class T>  requires  is_base_of_v<Base, T> struct D’
a.cpp:23:36: 附注：the expression ‘is_base_of_v<Base, T> [with T = Other]’ evaluated to ‘false’
   23 | template<typename T> requires std::is_base_of_v<Base, T>
      |                               ~~~~~^~~~~~~~~~~~~~~~~~~~~
```

</details>

这次我们终于知道 `T = Other` 了。Clang 的错误信息更清楚一些：

<details>
<summary>Clang Output</summary>

```console
❯ clang++ a.cpp -std=c++2a
a.cpp:36:5: error: constraints not satisfied for class template 'D' [with T = Other]
    D<Other> d1;
    ^~~~~~~~
a.cpp:23:31: note: because 'std::is_base_of_v<Base, Other>' evaluated to false
template<typename T> requires std::is_base_of_v<Base, T>
                              ^
1 error generated.
```

</details>


[^1]: GCC 从 6 开始支持一个叫做 Concept Lite 的 Concept 实验性版本，MSVC 从 VS2019 16.3 开始支持部分 Concept 的功能。
