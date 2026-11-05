#lang acf/scribble

@title[#:tag "05:4-language"]{描述关系的语言}

到这里，关系都是用函数模拟的：交出列表的函数，或者带 @racket[amb] 的函数。可是在 @racket[amb] 版的搜索里，两个关系的用法并不一样：

@racketblock[
(let* ([a (between l h)]
       [b (between a h)]
       [c (between b h)])
  (check (pyth? a b c))
  (list a b c))]

@racket[between] 是交出结果的函数，写在绑定的右边，取出一个数来；@racket[pyth?] 是谓词，只回答是或否，要靠 @racket[check] 才用得上。一个取，一个查。它们描述的却是同一类东西：@racket[between] 是边界与其间的数之间的关系，@racket[pyth?] 是三条边之间的关系。取与查的分别来自函数，不来自关系。

设想有一门语言，直接写关系。@racket[between] 和 @racket[pyth?] 在其中各有对应的关系，名字后面添一个上标 ᵒ：

@racketblock[
(define betweenᵒ (function->relation  between))
(define pythᵒ    (predicate->relation pyth?))]

@racket[(pythᵒ a b c)] 说的是 @racket[a]、@racket[b]、@racket[c] 满足勾股定理。@racket[between] 收两个数交出一个，@racket[betweenᵒ] 就有三个位置，结果排在最后：@racket[(betweenᵒ l h a)] 说的是 @racket[a] 在 @racket[l] 与 @racket[h] 之间。两个关系的写法一样，不再分取与查。搜索写成：

@racketblock[
(define (right-triangles l h)
  (run* (a b c)
    (betweenᵒ l h a)     (code:comment "l ≤ a ≤ h")
    (betweenᵒ a h b)     (code:comment "a ≤ b ≤ h")
    (betweenᵒ b h c)     (code:comment "b ≤ c ≤ h")
    (pythᵒ a b c)))      (code:comment "a² + b² = c²")]

与 @racket[amb] 版一行对一行：三个绑定成了三行 @racket[betweenᵒ]，@racket[check] 的一行成了 @racket[pythᵒ]，最后交出的 @racket[(list a b c)] 挪到了 @racket[run*] 后面，@racket[in-amb] 那一层也收进了 @racket[run*]。它读起来更像集合的写法：@racket[run*] 是花括号，@racket[(a b c)] 是竖线左边的形状，下面四行是竖线右边的条件，要同时成立。

这还只是想要的写法，@racket[function->relation]、@racket[predicate->relation]、@racket[run*] 都还没有。改写里有一处不只是换名字：@racket[a]、@racket[b]、@racket[c] 原来由 @racket[let*] 绑定，每一行右边算出一个值，交给左边的名字；现在它们列在 @racket[run*] 后面，是三个还不知道的数，四行条件各说了一件关于它们的事。没有了绑定，这三个名字是什么？一行 @racket[(betweenᵒ l h a)] 写在那里，又交出了什么？
