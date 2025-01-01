+++
title = "使用基于 Github issue 的留言系统"
template = "page.html" 
date = 2018-12-20
tags = ["meta"]
+++

流行的博客留言系统包括 Disqus 等，但是我并没有 Disqus 帐号，也并不想注册一个。考虑到该博客的受众应该都有 Github 帐号，采用基于 Github issue 的系统应该是合适的，而且还可以享受邮件提醒等功能。我选择了 [utteranc.es](https://utteranc.es) 的方案。

<!--more-->

在 Zola 下，直接将以下代码保存到 `templates/page.html` 即可。

```html
{% extends "even/templates/page.html" %}

{% block page_before_footer %}
<script src="https://utteranc.es/client.js"
        repo="peng1999/blog"
        issue-term="pathname"
        theme="github-light"
        crossorigin="anonymous"
        async>
</script>
{% endblock %}
```

给机器人授权后，会在文章第一次被评论后添加相应的 issue，也可以直接在 Github issue 下面评论。

