#lang acf

@title[#:style acf-style]{控制流的代数本质 · 第一部}

@;{系列引言等整个系列完结后再写；写作缘起与知乎回答以后放进后记（Noah
10/26）。}

@margin-note{书中代码针对最新版 Racket 编写。较旧的版本（例如 Linux 发
行版打包的版本）可能还缺少部分绑定。}

@margin-note{代码在 @c{#lang typed/racket/no-check} 下运行：类型标注使
用 Typed Racket 语法，但不会被类型检查器验证。这些标注是描述预期契约的
设计文档，并非机器检查的断言。}

读这本书只需要能读 Scheme：@racket[λ]、@racket[let]、基本的递归。别的
写法，用到的地方会交代。书中的例子都在生成这份文档时实际运行过，打印和
结果照录。

@table-of-contents[]

@include-section["01-call-cc/main.scrbl"]

@section[#:tag "glossary" #:style 'unnumbered]{术语表}

@(glossary-table)

@section[#:tag "symbols" #:style 'unnumbered]{符号表}

@(symbol-table)
