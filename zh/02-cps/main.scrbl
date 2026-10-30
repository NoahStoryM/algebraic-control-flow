#lang acf/scribble

@title[#:tag "02"
  #:style chapter-style]{箭头指向何方：CPS 与@tech{否定翻译}}

只用 λ 和函数调用，凭空拿不到当前@tech{延续}，所以 @racket[call/cc] 要捕获。可第一篇的阴阳谜题改写成 @tech[#:key "延续传递风格"]{CPS} 以后，原来要捕获的那些后续工作，已经写成函数，作为参数交来交去。要是整个程序都这样写，每一步余下的工作都由调用者交来，走到原来调用 @racket[call/cc] 的地方，当前@tech{延续}本来就在手里。还有什么需要捕获的吗？

@table-of-contents[]

@include-section["1-continuations.scrbl"]
@include-section["2-embedded.scrbl"]
@include-section["3-translation.scrbl"]
@include-section["4-conclusion.scrbl"]
@include-section["5-appendix.scrbl"]
