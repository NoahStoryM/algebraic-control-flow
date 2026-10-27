# Scribble 底本的写法

第一篇起，正文改用 Scribble 写（#47）。这里记录写法；共享的定义在 `acf.rkt`，样式在 `acf.css`。写法参照 ctp（Noah 10/26），要点也记在 STYLE.md「Scribble 写法」一节。

## 结构

仓库是一个 Racket 包（`info.rkt`），风格照 ctp：包名、库名都用缩写 `acf`；每种语言一份文档，文档名带语言后缀，中文是 `acf-zh`，以后英文是 `acf-en`（Noah 10/26）。按「部 → 篇 → 小篇」的树搭（#47、#91）：

```
zh/main.scrbl                 部：目录、各篇、术语表、符号表
zh/01-call-cc/main.scrbl      篇：标题，用 @include-section 串起各小篇
zh/01-call-cc/1-labels.scrbl  小篇
zh/01-call-cc/2-logic.scrbl
zh/01-call-cc/3-fixed-point.scrbl
zh/01-call-cc/4-conclusion.scrbl 结论与未解的线索；附录也各自单独成文件
```

- 每个文件以 `#lang acf/scribble` 开头（`scribble/lang/reader.rkt`、`lib/doc-lang.rkt`）：它就是 `scribble/manual` 加上 `scribble/example` 和 `acf.rkt` 的写法，不必再 `require`；`acf.rkt` 的 `defterm` 盖过 scribble/manual 自带的那个。要先 `raco pkg install --name acf`，`#lang acf/scribble` 才找得到。名字不用 `#lang acf`，把它留给以后（Noah 10/26）。
- 每行不超过 70 栏，中文字与全角标点算两栏。Scribble 会把行尾的换行排成一个空格，`#lang acf/scribble` 读入时去掉两侧都是中文字（含全角标点）的换行（`lib/cjk-join.rkt`），所以中文段落可以在任意两个字之间折行，排出来不多空格；中文与代码、英文之间的换行照常排成一个空格。Chrome 不会自己去掉这种换行（Firefox 会），所以这一步不能省。
- `racket tools/wrap-scrbl.rkt 文件…` 先把每段连成一行再重新折：能在空格处或中文标点之后折就优先这样折，标点不放在行首，`--check` 只检查。代码块里的长行要手工按 Racket 的缩进改。
- 部的 `@title` 带 `#:style acf-style`；篇的 `@title` 带 `#:style chapter-style`，HTML 里每个小篇单独成页。
- 小篇文件里，`@title` 是小篇名，`@section` 对应 .md 里的「#」，`@subsection` 对应「##」，`@subsubsection` 对应「###」。
- 篇的引言写在篇的 `main.scrbl`，小篇之前；读者须知暂放系列前言 `zh/main.scrbl`。标题之间要有文字过渡：小篇标题、节标题后面先有一两句话，再接下一级标题。

构建（Racket 用最新版，AI 的环境里先运行 `sh tools/setup-racket.sh`，见 CONTRIBUTING.md）：

```sh
export LC_ALL=C.UTF-8
raco pkg install --name acf   # 在仓库根目录：装上依赖、编译、生成文档，打开 doc/acf-zh/index.html
raco setup --pkgs acf         # 之后改了正文，重新生成
scribble --text --dest build zh/main.scrbl # 纯文本，便于通读和比对
```

直接用 `scribble --htmls` 也能排，但要加 `++xref-in setup/xref load-collections-xref`，代码里的链接才找得到别的文档。

## 正文

| 写法 | 用途 |
| --- | --- |
| `@racket[call/cc]`、`@racket[(label)]` | 行内代码：标识符和能读成一个 S 表达式的片段（Scribble 自带）。着色并链接到对应库的文档 |
| `@c{#lang typed/racket/no-check}` | 读不成一个 S 表达式的代码片段，同样着色。含 `@` 时写 `@c\|{(k0 k3)@}\|` |
| `@tt{goto}` | 不是 Racket 绑定的名字（如 C 的 `goto`），只用等宽字 |
| `@math{¬p ∨ q}` | 行内公式（Scribble 自带），只用 Unicode；字母斜体。不另起别名（Noah 10/26） |
| `@ty{Label}` | 公式里的类型名，排成正体：`@math{¬¬@ty{Byte} → @ty{Byte}}` |
| `@mm{…}` | 独立成行的公式；需要空开时写 `@hspace[4]` |
| `@bold{…}`、`@italic{…}` | 加粗、斜体（不是术语时用） |
| `@hyperlink["url"]{文字}` | 外部链接 |
| `@margin-note{…}` | 旁注（原先的「注意」框），放在它所补充的段落的上面 |
| `@bold{练习}：…` | 练习，写成普通段落，不加框 |

正文里的 `@`、不配对的 `{` `}` 要写成 `@"@"`、`@"{"`。

## 代码块

照 amb 的 `amb-examples`，例子写 Scribble 原生的 `@examples`，生成文档时真的运行，打印和结果由 Racket 给出（Noah 10/26）。每个小篇建自己的求值器（`typed/racket/no-check`），前文假定已有的定义用隐藏的例子补上：

```scribble
@(define ev (make-acf-eval))
@examples[#:eval ev #:hidden
(define primitive-call/cc call/cc)
(define (goto l) (l l))
(define (label) (primitive-call/cc goto))]
```

| 写法 | 用途 |
| --- | --- |
| `@examples[#:eval ev #:label #f #:no-prompt …]` | 定义：照文件的样子排，运行但不显示结果 |
| `@examples[#:eval ev #:label #f …]` | 交互：带 `>` 提示符，下面是运行出来的打印与结果 |
| `@racketblock[…]` | 只排版、不运行：推导与等式、示意程序、不会停的程序 |
| `@out-block\|{…}\|` | 不带语言的输出（如矩阵），原样排 |

- 注释写 `(code:comment "…")`，空行写 `(code:blank)`；方括号里的 `;` 注释会被读取器丢掉。
- 不会停的程序要显示输出时，用 `(eval:alts 显示的程序 实际运行的程序)`：显示原程序，运行一个只截取前几行、再打出 `...` 的版本（见第一篇第三小篇的 `show-lines`）。
- 需要从头换一套定义时（例如以另一个原语为起点），另建一个求值器，不在同一个里覆盖。
- 例子求值出错（没有用 `eval:error` 标明的）时，文档构建失败。

## 术语

术语第一次出现时：

```scribble
@defterm[#:en "first-class labels"]{一等标签}
@defterm[#:en "Double Negation Introduction" #:abbr "DNI"]{双重否定引入}
@defterm{直觉主义逻辑}
```

排出来是「**一等标签**（*first-class labels*）」「**双重否定引入**（*Double Negation Introduction*，DNI）」「**直觉主义逻辑**」，并登记进部末的术语表，按第一次出现的顺序排列，每项链回定义处。哪些词注英文仍按 STYLE.md。`@defterm` 底下就是 Scribble 的 `@deftech`。

之后每次出现都写 `@tech{一等标签}`（照 ctp），读者从任何一处点进去都能跳回定义处。节标题里不加。复合词里的不加，例如「延续传递风格」里的「延续」、「双重否定引入」里的「否定」。同一术语在别处以不同字面出现时，写 `@tech[#:key "…"]{…}`。

## 符号

符号第一次定义处放一个不可见的锚：

```scribble
@defsym["¬p" "p 的否定：p → ⊥，延续的类型"]@math{¬p}
```

第一个参数按公式写（会用 `@math` 排版；类型名写 `@defsym[@ty{Label} "…"]`），第二个是符号表里的说明。正文里不显示，只在部末的符号表出现，链回这里。

## 引用

- 每个节标题（`@section`、`@subsection`、`@subsubsection`）都写标签，形如「篇号:英文短名」：`@section[#:tag "01:compare"]{比较}`。小篇的标签是 `01:1-labels` 这样的文件名，篇是 `01`。不写标签时 Scribble 用标题文字生成，改标题或换语言就变了；写死以后，链接稳定，各语言版本的同一节标签相同（Noah 10/26）。
- 回指照正文原来的说法写，链到那一节：`@xref["01:compare"]{比较一节}`。整个第一部是一份文档，篇与篇之间也这样写。
- 文献用 `scriblib/autobib`：在部的目录下放一个 `bib.rkt`，写 `(define-cite ~cite citet generate-bibliography #:style author+date-style)` 和各条 `make-bib`；正文 `@~cite[条目]` 或 `@citet[条目]`，部末 `@(generate-bibliography #:sec-title "参考文献")`。第一篇目前没有文献引用，所以还没建。
- 其他文档里的术语：`@tech/refer{continuation}`（Racket Reference）、`@tech/guide{…}`（Racket Guide），写法取自 ctp。要引别的文档，在 `acf.rkt` 里用 `define-tech` 再定义一个。
- 代码里的链接：代码块、`@racket` 和 `@c` 里的标识符按 `acf.rkt` 里 `for-label` 引入的库排版，着色并链接到它们的文档；`acf.rkt` 把这些绑定也交给引用它的文档，所以各 `.scrbl` 不用自己写 `for-label`。现在引入的有 `racket/base`、`racket/function`、`racket/control`、Typed Racket 的类型记号和 `control-context`（`label`、`goto`、`cc`……）。用到新的库，就在那里加。正文自己重新定义的名字也链接到库里对应的那一个（Noah 10/26）。
- 不直接引用其他文档的正文（STYLE.md）。

## 注释

脚注写 `@fn{…}`（`scriblib/footnote` 的 `note`）。HTML 里排在页脚，纯文本里就地展开。

## 核对

```sh
export LC_ALL=C.UTF-8
raco setup --pkgs acf                                  # 生成文档；例子出错就失败
racket tools/run-blocks.rkt zh/01-call-cc/main.scrbl   # 同样实例化文档，并数一数各类代码块
racket tools/cmp-forms.rkt zh/01-call-cc/main.scrbl zh/01-call-cc/code.rkt
racket tools/wrap-scrbl.rkt --check zh/main.scrbl zh/01-call-cc/*.scrbl
racket tools/cmp-conversion.rkt zh/0X-…/article.md zh/0X-…/main.scrbl   # 只在把一篇从 .md 转换过来时用
```

- `run-blocks.rkt` 对 .scrbl 不再逐处比对手写的打印：例子都由 Scribble 运行，它只是把文档实例化一次，任何例子出错就报错。
- `cmp-forms.rkt` 取 `@examples`（隐藏的除外）与 `@racketblock` 里的定义，核对它们都在 `code.rkt` 里（`tools/scrbl-source.rkt`，去掉 `code:comment`）。
- `cmp-conversion.rkt` 把 .scrbl 排成纯文本，逐段比对 .md 的正文文字；代码按 S 表达式比对，交互块只比输入。
