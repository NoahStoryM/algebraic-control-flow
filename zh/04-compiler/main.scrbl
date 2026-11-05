#lang acf/scribble

@title[#:tag "04"
  #:style chapter-style]{前沿回望之时：机器中的镜子}

@music{阿沃·帕特《镜中镜》}

@xref["03:delimited-cps"]{「定界延续与 CPS」}把几个例子手工化简成了 @tech[#:key "延续传递风格"]{CPS}，整理出几组对应表：@tech[#:key "延续传递风格"]{CPS} 把等待结果的工作作为参数传进去，@tech[#:key "A-范式"]{ANF} 用 @racket[let] 把它藏起来，@racket[shift] 在原来的位置把它取出来。@xref["03:open-threads"]{「未解的线索」}又回到这些表：每一组是同一个程序的几种写法，写法之间的转换是机械的，应当能交给一个程序去做。

这个程序一边读源代码，一边要记住读完当前这一块之后还得接着写什么：它也有自己的剩余工作。这份剩余工作能以哪些形式存在？@racket[fib] 在@xref["02:anf"]{「求值顺序与 ANF」}和@xref["02:cps"]{「延续与 CPS」}里就写过好几种。

@table-of-contents[]

@include-section["1-frontier.scrbl"]
@include-section["2-print.scrbl"]
@include-section["3-erase.scrbl"]
@include-section["4-named.scrbl"]
@include-section["5-broken.scrbl"]
@include-section["6-caller.scrbl"]
