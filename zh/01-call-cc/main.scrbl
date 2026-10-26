#lang scribble/manual
@(require "../../lib/acf.rkt")

@title[#:tag "01" #:style chapter-style]{标签成为逻辑之时：揭开 call/cc 的神秘面纱}

@racket[call-with-current-continuation]（简写 @racket[call/cc]，「以当前@tech{延续}调用」）是 Scheme 传统中最强大、也最令人畏惧的控制操作符之一。人们常说它是「美化的 goto」，这个说法可以照字面检验。C 的 @tt{goto} 只能跳到写死在代码里的标签。如果标签本身是一个值，可以存进变量、作为返回值，就成了@defterm[#:en "first-class labels"]{一等标签}。从@tech{一等标签}出发，离 @racket[call/cc] 还有多远？

读这一篇只需要能读 Scheme：λ、@racket[let]、基本的递归。别的写法，用到的地方会交代。文中的构造收在 Racket 包 @hyperlink["https://docs.racket-lang.org/context/index.html"]{@tt{control-context}} 里，可以边读边试。

@margin-note{书中代码针对最新版 Racket 编写。较旧的版本（例如 Linux 发行版打包的版本）可能还缺少部分绑定。}

@include-section["1-labels.scrbl"]
@include-section["2-logic.scrbl"]
@include-section["3-fixed-point.scrbl"]
