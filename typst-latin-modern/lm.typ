#let sample-text = "Sample Text"

#show table: box // Make it unbreakable

#let xy-table(xtitle, xargs, ytitle, yargs, disable: (), additional: ()) = {
  table(columns: xtitle.len() + 1,
    ..xtitle
      .enumerate()
      .map(((i, text)) => table.cell(x: i + 1, y: 0, text)),
    ..ytitle
      .enumerate()
      .map(((i, text)) => table.cell(x: 0, y: i + 1, text)),
    ..for row in array.range(ytitle.len()) {
      for col in array.range(xtitle.len()) {
        if not disable.contains((row, col)) {
          (table.cell(x: col + 1, y: row + 1,
            text(..xargs.at(col), ..yargs.at(row), sample-text)),)
        }
      }
    },
    ..additional,
  )
}

#let disable-list(matrix) = for row in array.range(matrix.len()) {
  for col in array.range(matrix.at(row).len()) {
    if matrix.at(row).at(col) == 0 {
      ((row, col),)
    }
  }
}

#let family-opsz(style, sz) = {
  let suffix = if sz == 10 { "" } else { " " + str(sz) }
  "Latin Modern " + style + suffix
}

#align(center, text(font: "Latin Modern Roman 12", weight: "bold", size: 20pt)[The Latin Modern Families])

#set text(font: "Latin Modern Mono", size: 10pt)

= Latin Modern Mono (20 fonts)

== Optical Size

#table(columns: (auto, auto),
  ..for opsz in (8, 9, 10, 12) {
    (str(opsz) + "pt", text(font: family-opsz("Mono", opsz), size: opsz * 1pt, sample-text))
  }
)

== Italic

#text(style: "italic", sample-text)

== Other Styles

#let repeat(elem, times) = {
  for _ in array.range(times) {
    (elem,)
  }
}

#let mono-table = xy-table(
  ([Light], [Regular], [Bold]),
  ((weight: 300), (), (weight: 700)),
  ([Normal], [Cond], [Caps], [Prop]),
  (
    (),
    (stretch: 65%),
    (font: "Latin Modern Mono Caps"),
    (font: "Latin Modern Mono Prop")
  ),
  disable: ((1, 1), (1, 2), (2, 0), (2, 2))
)

=== Upright

#mono-table

=== Oblique

#{
  set text(style: "oblique")
  mono-table
}

#pagebreak()
#set text(font: "Latin Modern Roman")

= Latin Modern Roman (34 fonts)

== Optical Size, Italic, and Bold

#{
  let matrix = (
    (1, 0, 0, 1, 0, 0),
    (1, 0, 0, 1, 0, 0),
    (1, 1, 0, 1, 0, 0),
    (1, 1, 1, 1, 0, 0),
    (1, 1, 1, 1, 0, 0),
    (1, 1, 1, 1, 1, 1),
    (1, 1, 1, 1, 0, 0),
    (1, 0, 1, 0, 0, 0),
  )
  let opsz-list = (5, 6, 7, 8, 9, 10, 12, 17)
  xy-table(
    ([Normal], [Italic], [Slanted], [Bold], [Bold Italic], [Bold Slanted]),
    (
      (), (style: "italic"), (style: "oblique"),
      (weight: "bold"), (weight: "bold", style: "italic"), (weight: "bold", style: "oblique")
    ),
    opsz-list.map(sz => str(sz) + "pt"),
    opsz-list.map(sz => (font: family-opsz("Roman", sz), size: sz * 1pt)),
    disable: disable-list(matrix),
    additional: (table.cell(x: 0, y: 0, [opsz]),)
  )
}

== Other Styles

#xy-table(
  ([Normal], [Oblique]),
  ((), (style: "oblique")),
  ([Caps], [Demi], [Dunhill], [Unslanted]),
  (
    (font: "Latin Modern Roman Caps"),
    (weight: 600),
    (font: "Latin Modern Roman Dunhill"),
    (font: "Latin Modern Roman Unslanted")
  ),
  disable: ((3, 1),)
)

#pagebreak()
#set text(font: "Latin Modern Sans")

= Latin Modern Sans (18 fonts)

== Optical Size, Bold

#{
  let opsz-list = (8, 9, 10, 12, 17)
  xy-table(
    ([Normal], [Oblique]),
    ((), (style: "oblique")),
    opsz-list.map(sz => str(sz) + "pt"),
    opsz-list.map(sz => (font: family-opsz("Sans", sz), size: sz * 1pt)),
    additional: (table.cell(x: 0, y: 0, [opsz]),)
  )
}

== Other Styles

#xy-table(
  ([Normal], [Oblique]),
  ((), (style: "oblique")),
  ([Bold], [Demi Cond], [Quotation], [Quotation Bold]),
  (
    (weight: "bold"),
    (weight: "semibold"),
    (font: "Latin Modern Sans Quotation"),
    (font: "Latin Modern Sans Quotation", weight: "bold")
  ),
)

#pagebreak()
#set text(font: "Latin Modern Serif")

= How to use these variants in Typst

== Optical Size

The default optical size is 10pt.
All optical sizes other than 10pt are available as separate font families.

```typst
#set text(font: original-family + " 12")
```

== Italic, Oblique(Slanted)

```typst
#set text(style: "italic")
#set text(style: "oblique")
```

== Light, Demi, Bold

```typst
#set text(weight: "light")
#set text(weight: "semibold")
#set text(weight: "bold")
```

== Cond

```typst
#set text(stretch: 66%)
```

== Other Styles

All other styles are available as separate font families.

```typst
#set text(font: original-family + " Caps") // For Mono and Roman
#set text(font: "Latin Modern Mono Prop")
#set text(font: "Latin Modern Roman Dunhill")
#set text(font: "Latin Modern Roman Unslanted")
#set text(font: "Latin Modern Sans Quotation")
```
