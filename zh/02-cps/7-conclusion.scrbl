#lang acf/scribble

@title[#:tag "02:conclusion"]{结论}

第一章的@xref["01:open-threads"]{「未解的线索」}先问：能不能只靠传递和调用@tech{延续}参数，完成原来的捕获与跳转？能。@racket[cps:call/cc] 什么也没有捕获，交给 @racket[proc] 的@tech{延续}来自它收到的参数 @racket[kp]；调用它能丢下手头的工作，靠的是 @racket[kp] 不回来。@xref["02:position"]{「计算的位置」}从右往左读过 @c{kp = ((neg f) kq)}：在这里的纯编码中，每一处的@tech{延续}，都是从出口那条@tech{延续}出发，由 @racket[neg] 这样的纯构造一环环接出来的。出口那一条，运行时由 @racket[anf:eval] 或 @racket[call/cc] 交进来。

@xref["01:watershed"]{「分水岭」}把控制分成两列：只消耗交到手里的否定，普通函数就写得出；要自行提供非@tech{空类型}的否定，就得借助 𝒞 之外的宿主控制能力。这条分界线还在，只是挪到了程序的边界上。边界以内，消耗、变换@tech{延续}的工作，@racket[neg]、@racket[flip]、@racket[∘𝒦]、@racket[cps:call/cc]，全都是 𝒞 里的纯函数，控制只是在已有的@tech{延续}之间选一条来调用。代价是这条边界要划在整个程序外面：每一步都得写成 @tech{CPS 箭头}，原样包一层 @racket[cps] 的宿主函数，里面的控制照旧要靠宿主；交给高阶原语的函数若也改成了 @tech{CPS 箭头}，调用它的原语也得照新的写法另写。

边界上，这里的纯编码运行一次，需要宿主交进一条@tech{终结延续}。@racket[uncps] 用 @racket[call/cc] 捕获运行开始那一刻的当前@tech{延续}，直接交进去。@racket[anf:eval] 不捕获，交进去的是另一条，@racket[a->⊥]：它一调用就 @racket[raise]，由外面 @racket[⊥->a] 的 handler 把答案交回这一次调用处。@racket[anf:eval] 模拟的，是当前@tech{延续}接收结果的那份作用。两者的类型读出来都是 @tech[#:key "双重否定消除"]{DNE}：@racket[anf:eval] 是 @racket[(∀ (a) (→ (¬¬ a) a))]，@racket[uncps] 里的 @racket[call/cc] 也是。@xref["01:program-type"]{「代入 Byte」}说过，把程序运行起来、在出口接收结果，就是一次 @tech[#:key "双重否定消除"]{DNE}。

这就回答了第一章「未解的线索」里的第二个问题，经典性藏在哪里：经典的控制有了纯的 @tech[#:key "延续传递风格"]{CPS} 表示，留在程序里面；提供@tech{终结延续}、运行编码并把答案交回宿主的 @tech[#:key "双重否定消除"]{DNE}，留在了编码之外，留在 @racket[anf:eval] 里。

@section[#:tag "02:open-threads"]{未解的线索}

@racket[anf:eval] 交进去的那一条是 @racket[a->⊥]。它的跳转来自 @racket[raise]，而跳转函数的返回类型是 @math{⊥}，@racket[(: goto (→ Label ⊥))] 就是这样。@racket[⊥->a] 再把答案接回来。按字面读，这对名字似乎在说 @math{a} 和 @math{⊥} 可以互相转化。但 @math{⊥} 是@tech{空类型}，没有元素，而 @math{a} 是一个完全正常的、有元素的类型。它们怎么可能互相转化？

程序的类型 @math{¬¬@ty{Byte}} 里也有一个 @math{⊥}：程序调用 @racket[exit] 以后不再回来，可进程终止以后，操作系统还在运行，接着处理退出码。对程序来说是终点的 @math{⊥}，从外面看并没有结束。@math{⊥} 到底是什么？

@racket[anf:eval] 的经典性，全系在这一对名字上：交出一条通向 @math{⊥} 的@tech{延续}，再从 @math{⊥} 那里把答案接回来。要是 @math{⊥} 不再是终点，这一步还需要 @racket[raise] 吗？@racket[anf:eval] 还是 @tech[#:key "双重否定消除"]{DNE} 吗？它的类型又该读成什么？
