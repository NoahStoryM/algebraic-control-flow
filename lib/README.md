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
```

- 每个文件以 `#lang scribble/manual` 开头，接一行 `@(require "../../lib/acf.rkt")`（部的文件写 `"../lib/acf.rkt"`）。
- 部的 `@title` 带 `#:style acf-style`；篇的 `@title` 带 `#:style chapter-style`，HTML 里每个小篇单独成页。
- 小篇文件里，`@title` 是小篇名，`@section` 对应 .md 里的「#」，`@subsection` 对应「##」，`@subsubsection` 对应「###」。
- 篇的引言写在篇的 `main.scrbl`，小篇之前。标题之间要有文字过渡：小篇标题、节标题后面先有一两句话，再接下一级标题。

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
| `@m{¬p ∨ q}` | 行内公式（Scribble 自带的 `math`），只用 Unicode；字母斜体 |
| `@ty{Label}` | 公式里的类型名，排成正体：`@m{¬¬@ty{Byte} → @ty{Byte}}` |
| `@mm{…}` | 独立成行的公式；需要空开时写 `@hspace[4]` |
| `@bold{…}`、`@italic{…}` | 加粗、斜体（不是术语时用） |
| `@hyperlink["url"]{文字}` | 外部链接 |
| `@margin-note{…}` | 旁注（原先的「注意」框），放在它所补充的段落前面 |
| `@bold{练习}：…` | 练习，写成普通段落，不加框 |

正文里的 `@`、不配对的 `{` `}` 要写成 `@"@"`、`@"{"`。

## 代码块

四种块，内容一律原样写在 `|{` 与 `}|` 之间（这样 `@` 和花括号不用转义）：

```scribble
@code-block|{
(define (goto l) (l l))
}|
```

| 写法 | 对应 tools/REPL.md 的 |
| --- | --- |
| `@code-block` | 定义块与示意块 |
| `@repl-block` | 交互块（`> ` 开头） |
| `@eq-block` | 等式块（顶层的 `=`，不执行） |
| `@out-block` | 不带语言标记的输出块（不执行） |

核对配置写成块的关键字参数，含义与 .md 时代的 `blocks.rktd` 相同，不再按「节标题 + 首行」定位：

```scribble
@repl-block[#:skip "阴阳谜题无限输出，由 code.rkt 限时检查"]|{ … }|
@code-block[#:reset #t]|{ … }|
@repl-block[#:stdout '(exact "C1: enter\n")]|{ … }|
```

可用的有 `#:skip "原因"`、`#:reset #t`、`#:stdout '(exact|prefix "…")`、`#:value '(equal v)`、`#:error "正则"`、`#:exit 0`。排版时忽略。

块的种类要和内容一致，核对工具会检查：`@repl-block` 以 `> ` 开始，`@eq-block` 有顶层的 `=`，`@code-block` 两者都不是。

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
@defsym["¬p" "p 的否定：p → ⊥，延续的类型"]@m{¬p}
```

第一个参数按公式写（会用 `@m` 排版；类型名写 `@defsym[@ty{Label} "…"]`），第二个是符号表里的说明。正文里不显示，只在部末的符号表出现，链回这里。

## 引用

- 节的标签写成「篇号:名字」：`@section[#:tag "01:compare"]{比较}`。小篇的标签是 `01:1-labels` 这样的文件名。
- 回指照正文原来的说法写，链到那一节：`@xref["01:compare"]{比较一节}`。整个第一部是一份文档，篇与篇之间也这样写。
- 文献用 `scriblib/autobib`：在部的目录下放一个 `bib.rkt`，写 `(define-cite ~cite citet generate-bibliography #:style author+date-style)` 和各条 `make-bib`；正文 `@~cite[条目]` 或 `@citet[条目]`，部末 `@(generate-bibliography #:sec-title "参考文献")`。第一篇目前没有文献引用，所以还没建。
- 其他文档里的术语：`@tech/refer{continuation}`（Racket Reference）、`@tech/guide{…}`（Racket Guide），写法取自 ctp。要引别的文档，在 `acf.rkt` 里用 `define-tech` 再定义一个。
- 代码里的链接：代码块、`@racket` 和 `@c` 里的标识符按 `acf.rkt` 里 `for-label` 引入的库排版，着色并链接到它们的文档；`acf.rkt` 把这些绑定也交给引用它的文档，所以各 `.scrbl` 不用自己写 `for-label`。现在引入的有 `racket/base`、`racket/control`、Typed Racket 的类型记号和 `control-context`（`label`、`goto`、`cc`……）。用到新的库，就在那里加。正文自己重新定义的名字也链接到库里对应的那一个（Noah 10/26）。
- 不直接引用其他文档的正文（STYLE.md）。

## 注释

脚注写 `@fn{…}`（`scriblib/footnote` 的 `note`）。HTML 里排在页脚，纯文本里就地展开。

## 核对

```sh
export LC_ALL=C.UTF-8
racket tools/run-blocks.rkt zh/01-call-cc/main.scrbl
racket tools/cmp-forms.rkt zh/01-call-cc/main.scrbl zh/01-call-cc/code.rkt
racket tools/cmp-conversion.rkt zh/0X-…/article.md zh/0X-…/main.scrbl   # 只在把一篇从 .md 转换过来时用
```

两个核对工具从篇的 `main.scrbl` 出发，跟着 `@include-section` 读各小篇，用法和结果与 .md 时一样（`tools/scrbl-source.rkt`）。`cmp-conversion.rkt` 把 .scrbl 排成纯文本，逐段比对 .md 的正文文字，代码块逐字比对。
