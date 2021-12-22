+++
title = "Inverse clip in TikZ"
date = 2019-12-22
+++

[Ti*k*Z] 虽然强大，但是也过于复杂。下面尝试绘制下面的图形。

![ellipse](../tikz.svg)

首先绘制一个直立的图形，再全局旋转。

```tex
\begin{tikzpicture}[rotate=20,even odd rule]
```

绘制实线部分，一个椭圆，一个半椭圆和两条直线。

```tex
\coordinate (move) at (0,3);
\draw (move) ellipse [x radius=1,y radius=0.4];
\draw (-1,0) -- +(move);
\draw (1,0) -- +(move);
\draw (1,0) arc (0:-180:1 and 0.4);
\draw[dashed] (1,0) arc (0:180:1 and 0.4);
```

接下来绘制带有遮挡关系的直线。这里需要使用一个辅助的样式 `invclip`，用于产生「剪除」的效果。`clip` 相当于一个蒙板，加上 `invclip` 后变为一个反向蒙板。

```tex
\tikzset{
  invclip/.style={
    insert path={ (-3,-2) -- (-3,5) -- (3,5) -- (3,-2) -- (-3,-2) }
  }
}
```

`\foreach` 只运行两次。针对同一条直线，第一次 `\sty` 为 `dashed`，`\inv` 为 `{}`；第二次 `\sty` 为 `{}`，`\inv` 为 `invclip`。

```tex
\foreach \sty/\inv in {dashed/{},{}/invclip} {
  \begin{scope}
    \path[clip,\inv]
      (-1,0)
      -- +(move) -- ($(move)+(1,0)$)
      -- (1,0) arc (0:-180:1 and 0.4);
    \draw[\sty,thick] (0,4) -- (0,-1);
  \end{scope}
}
\end{tikzpicture}
```

[Ti*k*Z]: https://en.wikipedia.org/wiki/PGF/TikZ

