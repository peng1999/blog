+++
title = "用 Perl 做查找替换"
date = 2022-01-01
tags = ["programming", "perl"]
+++

现在需要把一篇文章中两个中文字符中的回车给删掉。这时候需要用到支持 Unicode 的正则表达式。这时候我们还是用最强大的字符处理语言 Perl 来搞。命令如下：

```sh
perl -CSAD -0p -i.bak -e 's/(\p{category=Po}|\p{sc=Han})\n *(\p{sc=Han})/$1$2/gms' file.md
```

如果不涉及 Unicode 处理，可以不用加 `-CSAD`，如果处理不跨行，可以不用 `-0`，如果不需要备份文件，可以删去 `.bak`。
