#lang acf/scribble

@title[#:tag "02"
  #:style chapter-style]{箭头指向何方：CPS 与否定翻译}

@music{巴赫《平均律钢琴曲集》第一册 C 大调前奏曲}

上一章里，当前@tech{延续}要通过 @racket[call/cc] 捕获：只用 @racket[λ] 和函数调用，凭空拿不到它。可那一章末尾，阴阳谜题换了一种写法，原来由 @racket[let/cc] 捕获的@tech{延续}，成了明明白白传来传去的参数。

要是整个程序都这样写，走到原来调用 @racket[call/cc] 的地方，当前@tech{延续}就是手上的参数，捕获似乎无事可做。那条分水岭还在吗？经典的控制又藏到了哪里？

@table-of-contents[]

@include-section["1-anf-cps.scrbl"]
@include-section["2-split.scrbl"]
@include-section["3-embedded.scrbl"]
@include-section["4-arrows.scrbl"]
@include-section["5-where.scrbl"]
@include-section["6-translation.scrbl"]
@include-section["7-conclusion.scrbl"]
@include-section["8-appendix.scrbl"]
