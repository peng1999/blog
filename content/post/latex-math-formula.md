+++
title = "LaTeX 公式"
template = "page.html" 
date = 2019-08-07
lastmod = 2024-12-29
tags = ["latex"]
+++

\\(\\mathrm{\\LaTeX}\\) 是一款非常优秀的文档准备系统，它强大的数学排版功能举世闻名。由于 [Mathjax](https://www.mathjax.org/) 的广泛采用，\\(\\mathrm{\\LaTeX}\\) 数学公式也成为了 Web 技术上数学公式排版的事实标准。但 \\(\\mathrm{\\LaTeX}\\) 的学习曲线陡峭，基本的命令难以轻松应对实际写作中遇到的复杂公式。本文选取并实现了 [\\(\textit{The $\TeX$ book}\\)](https://ctan.org/pkg/texbook) 第 18 章末尾提供的 20 个 Chanllenge。以期为想要深入学习 \\(\\mathrm{\\LaTeX}\\) 公式排版的读者提供参考。

<!--more-->

Knuth 在 The \\(\mathrm{\TeX}\\)book 的附录中给出了全部习题的答案，但全部使用的是原始的 \\(\mathrm\TeX\\) 命令，而本文则采用了适用于 \\(\\mathrm{\\LaTeX}\\) 的命令。为提供最大兼容性，本文原则上只使用 \\(\\mathrm{\\LaTeX}\\) 与 AMS 宏集提供的命令排版数学公式。一个例外是 `commath` 宏包提供的 `\dif` 命令。但即使不引用这个宏包，也可以轻易地通过定义 `\DeclareMathOperator{\dif}{d\!}` 来使用这个命令。

这篇文章是用 \\(\\mathrm{\\LaTeX}\\) 写的，目前只有 [PDF 版本](TeXbookFormula.pdf)。你也可以前往 [Github](https://github.com/peng1999/blog/blob/master/static/latex-math/TeXbookFormula.pdf) 在线阅读

文档的源码[在这里](TeXbookFormula.tex)。
