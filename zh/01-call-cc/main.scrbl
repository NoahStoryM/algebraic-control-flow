#lang scribble/manual
@(require "../../lib/acf.rkt")

@title[#:tag "01" #:style chapter-style]{标签成为逻辑之时：揭开 call/cc 的神秘面纱}

@;{第一篇的引言：占位，第 3 步按大纲第 0 节重写。写作缘起与知乎回答不放这里，以后放进后记（Noah 10/26）。}

这一篇以 C 语言风格的 @c{goto} 和 @c{label} 为原语，从零推导出 @c{call/cc}。文中的这些构造收在 Racket 包 @hyperlink["https://docs.racket-lang.org/context/index.html"]{@c{control-context}} 里，可以边读边试。

@notice{书中代码针对最新版 Racket 编写。较旧的版本（例如 Linux 发行版打包的版本）可能还缺少部分绑定。}

@include-section["1-labels.scrbl"]
@include-section["2-logic.scrbl"]
@include-section["3-fixed-point.scrbl"]
