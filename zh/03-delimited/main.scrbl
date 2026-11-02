#lang acf/scribble

@title[#:tag "03"
  #:style chapter-style]{世界尽头有何物：我们早已熟知的边界}

@music{梅西安《时间终结四重奏》第一乐章}

上一章的嵌入语言要运行，靠 @racket[anf:eval] 交进一条@tech{终结延续} @racket[a->⊥]。它一调用就 @racket[raise]，外面的 @racket[⊥->a] 接住答案，交回调用处。@xref["02:open-threads"]{「未解的线索」}认出，@racket[anf:eval] 的经典性全系在这一对名字上：交出一条通向 @math{⊥} 的@tech{延续}，再从 @math{⊥} 那里把答案接回来。

可答案接回来以后，计算并没有到头：调用 @racket[anf:eval] 的那段宿主代码，拿着答案接着算。对嵌入程序是终点的 @math{⊥}，从外面看，只是一次调用返回了。要是 @math{⊥} 不再是终点，还需要 @racket[raise] 吗？@racket[anf:eval] 还是 DNE 吗？它的类型又该读成什么？

一段计算算完，把结果交出去，外面接着算，这件事我们每天都在做：调用一个函数时，发生了什么？

@table-of-contents[]

@include-section["1-answer.scrbl"]
@include-section["2-local.scrbl"]
@include-section["3-delimited.scrbl"]
@include-section["4-meta.scrbl"]
