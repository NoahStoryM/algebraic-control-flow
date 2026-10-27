#lang acf/scribble

@title[#:tag "01:conclusion"]{结论}

@tech{标签}、@racket[cc]、@racket[call/cc] 交出的都是@tech{延续}，
而只用 @racket[λ] 和函数调用，凭空写不出一个非空类型的@tech{延
续}。@xref["01:watershed"]{「分水岭」}沿着这条线分成两列：
调用@tech{延续}、写一个函数等着@tech{延续}，
只用交到手里的那条；@racket[call/cc] 和 @racket[cc]
却凭空拿到了当前@tech{延续}。

代入具体的类型，这条线又看得更细。程序是一个 @math{¬¬@ty{Byte}}，
它等待的那条@tech{延续}不由它自己写出，而是在启动时由操作系统交给它；
三重否定律连这样一条交来的@tech{延续}也用不着；到了
@math{@ty{Label}}，层数分不清角色，同一个@tech{标签}既当@tech{延续}又
当值，阴阳谜题就这样永远振荡下去。

@section[#:tag "01:open-threads"]{未解的线索}

但我们小心避开了一个问题。编程语言建立在@tech{构造性}的基础之
上：@tech{Curry-Howard 对应}把程序与直觉主义证明配对，
而在@tech{直觉主义逻辑}中，@tech{排中律}不是定理。
然而我们一直在愉快地使用@tech{排中律}、Clavius 律和 DNE，
仿佛它们是天经地义的。

这怎么可能？一个构造性语言如何支持经典推理？

阴阳谜题的 CPS 分解提供了一条线索。当我们只用 @racket[λ]
和函数调用（没有 @racket[call/cc]、没有 @racket[goto]、没有可变状态）
重写谜题时，表达能力没有任何损失。经典的控制流仍然存在，
只是被@bold{换了一种方式编码}：作为显式的@tech{延续}传递。在证明论中，
这种编码叫做@defterm[#:en "negative translation"]{否定翻译}。

还有另一根线头。程序类型 @math{¬¬@ty{Byte}} 中的 @math{⊥}
不是世界的终结：进程终止后，OS 继续运行。@math{⊥}
只是@italic{这个进程}的终结，不是所有计算的终结。
它是一个@italic{相对的} bottom，不是绝对的。

如果我们能在程序@italic{内部}拥有相对的 @math{⊥} 呢？如果函数调用，
而不仅仅是 OS，也能充当定界符呢？

但那些
是@hyperlink["https://zhuanlan.zhihu.com/p/2024852076593694078"]{后续
文章}的故事了。
