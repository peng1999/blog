# My Blog

## 本地预览

需要 Hugo Extended 和 Dart Sass（当前验证版本：Hugo 0.168.0、Dart Sass 1.105.2）。macOS 安装：

```sh
brew install hugo dart-sass
hugo server --bind 0.0.0.0
```

请使用 Homebrew 或 [Dart Sass 官方二进制发行包](https://github.com/sass/dart-sass/releases)。`npm install sass` 安装的纯 JS 版本不支持 Hugo 所需的 embedded 协议，不能用于这里的 Hugo 构建。

## Even 主题兼容性

主题修复直接维护在 `themes/even` 子模块中，`.gitmodules` 指向 `peng1999/hugo-theme-even` fork。Sass 模块迁移、Hugo head 模板适配、空目录脚本修复及回归测试均属于主题仓库；站点附加 CSS 仍在 `static/css/main.css`。详细说明见 [主题文档](themes/even/README-zh.md)。

提交时先在主题仓库提交修复，再在主仓库记录新的子模块提交指针；推送时也先推送主题提交，确保 CI 能拉取对应版本。

CI 固定使用 Hugo 0.168.0 和 Dart Sass 1.105.2 官方 Linux 二进制；PR 只运行检查，master 推送和手动触发继续部署 GitHub Pages。构建遇到警告就失败，避免未来兼容性问题被忽略。

## 本地检查

回归测试需要 Node.js 22 或更新版本，无需安装 npm 依赖：

```sh
node --test themes/even/tests/theme.test.cjs
sass --no-source-map --fatal-deprecation=1.105.2 themes/even/assets/sass/main.scss /tmp/newblog-theme.css
hugo --ignoreCache --minify --panicOnWarning --printPathWarnings
```

升级 Hugo 或 Sass 时，同步修改 CI 的版本和 Sass 检查参数，并检查首页、分页、归档、标签、带目录及无目录文章、图片预览和移动端菜单。

[<img src="https://api.gitsponsors.com/api/badge/img?id=141370986" height="20">](https://api.gitsponsors.com/api/badge/link?p=q7TBb4NtOL7CLD64EmTn6HpX21Ui5uhH+Vtns245JGctOr9wg6BeLDUkStii0FMuRxbpCopH18IEJ/PfIfW9NcyUaG3/lsRehOz0KvIkUOGxkR5d6w2e54Ig0SxgaRkTHlYYterfvuzY8v+ZDd8HYw==)
