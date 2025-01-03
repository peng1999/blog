+++
title = "你应该使用 Neovim"
template = "page.html"
date = 2019-04-19
tags = ["linux"]

+++

本文旨在说服读者将自己的文本编辑工具从 Vim 转到 Neovim。
<!--more-->

Neovim 是 Vim 编辑器的一个分支。项目开始的时候还是 2014 年，为了解决 Vim 存在的一些长期存在的问题，巴西程序员 Thiago de Arruda Padilha（[@tarruda](https://github.com/tarruda)）
启动了这个项目。

我从高一起开始使用 Vim，至今也有快有三年了。2017 年年末，经过一番比较，我就转到了 Neovim 。但不久前在与学长的讨论中，我才发现 Neovim 比 Vim 更好的地方不是三言两语就能说清楚的。根据我在 Vim 8.0 刚发布时的印象（我就是在那时转到 Neovim
的），Neovim 和 Vim 的一个最明显的区别就是 Neovim 有一个内置的真正终端，同时它又是一个真正的缓冲区，可以使用跳转到文件、搜索等功能。但是这个相当棒的功能在 Vim 8.1 中已经被实现了。事实上，当初 Neovim 的许多优秀功能，例如异步通信等都已经在 Vim 8 上得到了实现。~~截止到本文写作之时，Vim 的这两个分支在主要功能上已经没有什么大的区别了。~~（见下文）

然而如果我们不从功能，而从项目的维度上去考虑，我们会发现 Vim 8 的推出，很大程度上是受了 Neovim 的影响，前面提到的异步通信和内置终端，都是在 Neovim 中首先实现的。换言之，在编辑器的开发上面，Neovim 是领先于 Vim 的。这与项目组织方式有关。虽然 Vim 也在 2014 年启用了[官方 Github 仓库](https://github.com/vim/vim/)，但 Vim 的主要开发和讨论还是在邮件列表上。这当然有其历史原因，但 Neovim 完全拥抱 Github 的
[开发方式](https://github.com/neovim/neovim/blob/master/CONTRIBUTING.md)显然更友好。另外，Neovim 长期在 [Google Summer of Code](https://summerofcode.withgoogle.com/) 的列表中，每年都有大学生为 Neovim 项目添加有趣的功能。例如在 2018 年的 GSoC 中，
Utkarsh Maheshwari 对 UI 子系统底层做了修改，使得插件可以创建自定义的浮动窗口。下图是插件 [coc.nvim](https://github.com/neoclide/coc.nvim/) 的效果。

![coc插件在 Neovim 中的效果](https://neovim.io/images/nvim-0.4.0-floatwin-chemzqm.gif)

基于上述的原因，Neovim 在很多小地方都比背着历史包袱的 Vim 要做得好。例如

1. Neovim 不考虑 Vi 兼容的问题，所以有一个比较好的默认配置，在全新安装的情况下也可以很好地工作；
2. Neovim 遵守 [XDG Base Directory 规范](https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html)；
3. Neovim 支持一些现代终端模拟器的功能，例如它可以在插入模式和普通模式下使用不同形状的光标，可以识别粘贴行为并自动进入 paste 模式等。

另外，Neovim 作为 Vim 的竞争者，同时加快了 Vim 和 Neovim 的发展。如果没有 Neovim 项目的压力，Vim 8 还不知道要等到什么时间才会发布，我们这些用户也只能一直使用几十年前就已经存在的老式 Vim。长远来看，使用 Neovim，增加它的用户量和影响力，是有利于所有人的。

---
2022 年 5 月更新

时过境迁，如今 Vim 的最新版本是 8.2.4609，而 Neovim 也发布了 0.7 版本。现在来看，虽然 Vim 已经补足了许多功能，但是其开发仍然比 Neovim 要滞后。具体可见如下几点：

- 如今 Neovim 的 Lua 配置已经走上正轨，可以使用 Lua 完成几乎所有配置（无需调用 `vim.cmd`）。而 Vim9 的正式发布还不知要等到什么时候。
- Neovim 中的 Virtual Text 可以让插件在编辑框中显示不能编辑的虚拟文本，这使得像 VS Code 那样的 Inlay hint 成为可能。另外 GitHub 和 OpenAI 开发的 AI 代码补全软件 Copilot 的 Vim 插件也因为使用了 virtual text 功能而成为了 Neovim 独占。而 Vim 的开发者到现在也[不太愿意][virtual]添加这一功能。
- Neovim 中提供了良好的 Tree-sitter 支持，而 Vim 则要[在 Vim9 之后][tree-sitter]再考虑这个功能……

[virtual]: https://github.com/vim/vim/issues/7553
[tree-sitter]: https://github.com/vim/vim/issues/8924#issuecomment-933006595

---

## 参考网站

[1] <https://neovim.io/>

[2] <https://github.com/vim/vim>

[3] <https://zhuanlan.zhihu.com/p/21364426>
