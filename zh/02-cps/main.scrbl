#lang acf/scribble

@title[#:tag "02"
  #:style chapter-style]{箭头指向何方：CPS 与否定翻译}

第一篇里，当前@tech{延续}要通过 @racket[call/cc] 捕获：只用 @racket[λ] 和函数调用，凭空拿不到它。

可那篇末尾，阴阳谜题换了一种写法。每一步还没做完的工作都写成一个函数，作为参数交给下一步；@tech{延续}不再藏在幕后，而是明明白白地在参数里传来传去。

要是整个程序都这样写呢？每个函数都多收一个参数，代表算完以后要做的事。走到原来调用 @racket[call/cc] 的地方，当前@tech{延续}就是手上这个参数，还有什么需要捕获的吗？

@table-of-contents[]

@include-section["1-continuations.scrbl"]
@include-section["2-embedded.scrbl"]
@include-section["3-translation.scrbl"]
@include-section["4-conclusion.scrbl"]
@include-section["5-appendix.scrbl"]
