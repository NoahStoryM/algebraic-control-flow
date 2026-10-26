#lang scribble/manual
@(require "../lib/acf.rkt")

@title[#:style acf-style]{控制流的代数本质 · 第一部}

这一部用 Racket 与 Typed Racket，从 @c{goto} 和 @c{label} 出发，一步步造出延续、CPS、定界延续、关系、单子与代数作用。新的结构总是先在一段具体的程序里出现，看清它做了什么，再给它名字，指出它在逻辑里对应什么。

起点是我在知乎上的一个@hyperlink["https://www.zhihu.com/question/21954238/answer/1892887870676653657"]{回答}：它讨论 @c{call/cc} 与 @c{goto}、@c{label} 的联系，并用这层联系解释阴阳谜题。第一篇把那个思想实验完整地走一遍，以 C 语言风格的 @c{goto} 和 @c{label} 为原语，从零推导出 @c{call/cc}。

文中的这些构造收在 Racket 包 @hyperlink["https://docs.racket-lang.org/context/index.html"]{@c{control-context}} 里，可以边读边试。

@notice{书中代码针对最新版 Racket 编写。较旧的版本（例如 Linux 发行版打包的版本）可能还缺少部分绑定。}

@table-of-contents[]

@include-section["01-call-cc/main.scrbl"]

@section[#:tag "glossary" #:style 'unnumbered]{术语表}

@(glossary-table)

@section[#:tag "symbols" #:style 'unnumbered]{符号表}

@(symbol-table)
