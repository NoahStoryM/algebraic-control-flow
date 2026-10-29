#lang acf/scribble

@title[#:tag "01:conclusion"]{结论}

@tech{标签}、@racket[cc]、@racket[call/cc] 交出的都是@tech{延续}，
而只用 @racket[λ] 和函数调用，不靠永不终止的程序，也不用自指类型，
凭空写不出一个非空类型的@tech{延续}。@xref["01:watershed"]{「分水
岭」}沿着这条线分成两列：调用@tech{延续}、写一个函数等着@tech{延续}，
只用交到手里的那条；@racket[call/cc] 和 @racket[cc]
却凭空拿到了当前@tech{延续}。

代入具体的类型，这条线看得更细：程序的那条@tech{延续}由操作系统交来，
三重否定律不需要另外交来的@tech{延续}；否定塔上，两种逻辑只差在第 0
层。到了 @racket[Label]，同一个@tech{标签}既当@tech{延续}又当值，
阴阳谜题就这样一直运行下去。

@section[#:tag "01:open-threads"]{未解的线索}

还有一个问题没有回答。@xref["01:watershed"]{「分水岭」}说，只用
@racket[λ] 和函数调用，凭空拿不到当前@tech{延续}。阴阳谜题改写成 CPS
以后，@tech{标签}仍然会被交给自己，@racket[Label] 的自指没有消失；
可原来需要捕获的那些后续工作，已经写成了函数，作为参数传来传去。

如果整个程序都这样安排，每一步余下的工作都作为参数交来，
那么走到原来调用 @racket[call/cc] 的地方，能不能只靠传递和调用这个参
数，完成原来的捕获与跳转？
