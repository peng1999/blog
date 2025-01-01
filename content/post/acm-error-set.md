+++
title = "ACM 错误集"
template = "page.html" 
date = 2018-09-20T20:26:00+08:00
tags = ["acm"]
+++

以下是平时做题时造成不能一遍AC的原因。
<!--more-->

### 1. [Codeforces Round #510 (Div. 2) Problem B](http://codeforces.com/contest/1042/problem/B)

> ⚠ 样例错误

把位操作`&`和`|`弄反。

### 2. [PAT (Advanced Level) Practice 1001](https://pintia.cn/problem-sets/994805342720868352/problems/994805528788582400)

数字 1000 写成 100。

### 3. [PAT (Advanced Level) Practice 1002](https://pintia.cn/problem-sets/994805342720868352/problems/994805526272000000)

没有注意到题中 non-zero 的条件。

### 4. [PAT (Advanced Level) Practice 1003](https://pintia.cn/problem-sets/994805342720868352/problems/994805523835109376)

忘记小顶堆应该使用 `priority_queue<T, vector<T>, greater<>>`。

### 5. [PAT (Advanced Level) Practice 1022](https://pintia.cn/problem-sets/994805342720868352/problems/994805480801550336)

没有输出数字的前导零。

`printf("%013lf", num);`的等价方法：

```cpp
cout << setfill('0') << setw(13) << num;
```
