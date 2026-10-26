#lang scribble/manual
@(require "../../lib/acf.rkt")

@title[#:tag "01" #:style chapter-style]{标签成为逻辑之时：揭开 call/cc 的神秘面纱}

这一篇以 C 语言风格的 @c{goto} 和 @c{label} 为原语，从零推导出 @c{call/cc}。

读它只需要能读 Scheme：λ、@c{let}、基本的递归。别的写法，用到的地方会交代。文中的构造收在 Racket 包 @hyperlink["https://docs.racket-lang.org/context/index.html"]{@c{control-context}} 里，可以边读边试。

@notice{书中代码针对最新版 Racket 编写。较旧的版本（例如 Linux 发行版打包的版本）可能还缺少部分绑定。}

@include-section["1-labels.scrbl"]
@include-section["2-logic.scrbl"]
@include-section["3-fixed-point.scrbl"]
