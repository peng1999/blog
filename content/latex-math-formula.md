+++
title = "LaTeX 公式"
template = "page.html" 
date = 2019-08-07
[taxonomies]
tags = ["latex"]
+++

## 摘要

\\(\LaTeX\\) 是一款非常优秀的文档准备系统，它强大的数学排版功能举世闻
名。由于 [Mathjax](https://www.mathjax.org/) 的广泛采用，\\(\LaTeX\\) 数学公式也成为了 Web 技术上数学
公式排版的事实标准。但 \\(\LaTeX\\) 的学习曲线陡峭，基本的命令难以轻松应
对实际写作中遇到的复杂公式。本文选取并实现了 The \\(\TeX\\)book 第 18 章
末尾提供的 20 个 Chanllenge。以期为想要深入学习 \\(\LaTeX\\) 公式排版的读
者提供参考。

Knuth 在 The \\(\TeX\\)book 的附录中给出了全部习题的答案，但全部使用
的是原始的 \\(\TeX\\) 命令，而本文则采用了适用于 \\(\LaTeX\\) 的命令。为提供最大
兼容性，本文原则上只使用 \\(\LaTeX\\) 与 AMS 宏集提供的命令排版数学公式。
一个例外是 `commath` 宏包提供的 `\dif` 命令。但即使不引用这个宏包，也可
以轻易地通过定义 `\DeclareMathOperator{\dif}{d\!}` 来使用这个命令。

这篇文章是用 LaTeX 写的，目前只有 [PDF 版本](latex-math/TeXbookFormula.pdf)。你也可以前往 [Github](https://github.com/peng1999/blog/blob/master/content/latex-math/TeXbookFormula.pdf) 在线阅读

文档的源码[在这里](latex-math/TeXbookFormula.tex)。
