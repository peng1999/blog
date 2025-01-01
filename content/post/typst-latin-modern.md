+++
title = "在 Typst 中使用 Latin Modern 家族"
date = 2024-01-24
lastmod = 2024-12-30
tags = ["typst", "typography"]
+++

高德纳在开发 TeX 时，也设计了一套字体叫 Computer Modern，作为 TeX 的默认字体。然而当时字体是采用 METAFONT 制作的，和当今的字体标准 OpenType 并不兼容。Latin Modern 通过技术手段将 Computer Modern 转换到了 OpenType 格式，并且做了扩充和微调。所以我们在 Typst 中也可以调用 Latin Modern 字体。

<!--more-->

下面是一个在 Typst 中使用 Latin Modern 字体的 demo，显示了 Latin Modern 字体家族的全部 72 种字体。

[在这里查看](./lm.pdf)（[源码](./lm.typ)）

~今年~ 2025 年 Typst 应该就要支持 HTML 导出功能，届时可以将 PDF 文件换成 HTML。

