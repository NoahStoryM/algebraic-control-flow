#lang acf/scribble

@title[#:tag "01:conclusion"]{结论}

@tech{标签}、@racket[cc]、@racket[call/cc] 交出的都是@tech{延续}，
而只用 @racket[λ] 和函数调用，凭空写不出一个非空类型的@tech{延
续}。@xref["01:watershed"]{「分水岭」}沿着这条线分成两列：
调用@tech{延续}、写一个函数等着@tech{延续}，
只用交到手里的那条；@racket[call/cc] 和 @racket[cc]
却凭空拿到了当前@tech{延续}。

代入具体的类型，这条线又看得更细。程序等待的那条@tech{延续}由操作系统
交来；三重否定律连这样一条交来的@tech{延续}也用不着；到了
@racket[Label]，层数分不清角色，同一个@tech{标签}既当@tech{延续}又当
值，阴阳谜题就这样一直运行下去。

@section[#:tag "01:open-threads"]{未解的线索}

还有一个问题没有回答。@tech{Curry-Howard 对应}把程序与直觉主义证明配
对，而在@tech{直觉主义逻辑}中，@tech{排中律}不是定理。可我们一直靠
@racket[cc]、@racket[call/cc] 在用@tech{排中律}、Clavius 律和 DNE。
这和@xref["01:where-fails"]{「对应关系在哪里失效」}说的不是一回事：
那里是不终止和自指，让本应为空的类型有了值；这里是一条条经典定律，
由捕获@tech{延续}实现。

这怎么可能？一个构造性语言如何支持经典推理？

阴阳谜题的 CPS 分解提供了一条线索。当我们只用 @racket[λ]
和函数调用（没有 @racket[call/cc]、没有 @racket[goto]、没有可变状态）
重写谜题时，谜题照样写得出来，输出也一样。经典的控制流仍然存在，
只是被@bold{换了一种方式编码}：作为显式的@tech{延续}传递。在证明论中，
这种编码叫做@defterm[#:en "negative translation"]{否定翻译}。

还有另一根线头。程序类型 @math{¬¬@ty{Byte}} 中的 @math{⊥}
不是世界的终结：进程终止后，OS 继续运行。@math{⊥}
只是@italic{这个进程}的终结，不是所有计算的终结。
它是一个@italic{相对的} bottom，不是绝对的。

如果我们能在程序@italic{内部}拥有相对的 @math{⊥} 呢？如果函数调用，
而不仅仅是 OS，也能充当定界符呢？

@;{第二篇转成 .scrbl 后，这里改成指向第二篇的
@xref（STYLE.md「引用」）。} 但那些是后面的故事了。
