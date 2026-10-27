#lang acf/scribble

@title[#:tag "01"
  #:style chapter-style]{标签成为逻辑之时：揭开 call/cc 的神秘面纱}

@racket[call-with-current-continuation]（简写 @racket[call/cc]，
「以当前@tech{延续}调用」）是 Scheme 传统中最强大、
也最令人畏惧的控制操作符之一。人们常说它是「美化的 goto」，
这个说法可以照字面检验。C 的 @tt{goto} 只能跳到写死在代码里
的@defterm[#:en "label"]{标签}。如果@tech{标签}本身是一个值，
可以存进变量、作为返回值，它就成了一等的值。从这样的@tech{标签}出发，
离 @racket[call/cc] 还有多远？

@table-of-contents[]

@include-section["1-labels.scrbl"]
@include-section["2-logic.scrbl"]
@include-section["3-fixed-point.scrbl"]
