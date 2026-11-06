#lang acf/scribble

@title[#:tag "05:7-logic"]{与逻辑的对应}

@racket[∘ᵒ] 是照着集合的写法写下来的：「存在」写成 @racket[fresh]，「并且」写成两行条件，「在关系里」写成把关系用在项上。关系语言里的其余几样，也各有逻辑里的对应。

@section[#:tag "05:logic-table"]{一张对照表}

把这门语言里的写法、逻辑里的说法、表上的操作并排放：

@tabular[#:style 'boxed #:row-properties '(bottom-border ())
  (list
   (list @elem{关系语言} @elem{逻辑} @elem{表})
   (list @racket[succeed] @math{⊤} @elem{零元关系 {()}})
   (list @racket[fail] @math{⊥} @elem{零元关系 {}})
   (list @racket[(== t1 t2)] @math{t₁ = t₂} @elem{使两项相等的那些取值})
   (list @racket[(conj g1 g2)] @math{g₁ ∧ g₂} @elem{按共有的列拼起来})
   (list @racket[(disj g1 g2)] @math{g₁ ∨ g₂} @elem{两张表并起来})
   (list @racket[(fresh (x) g)] @math{∃x. g} @elem{遮住一列})
   (list @racket[(run* (x) g)] @math{{x ∣ g}} @elem{读出整张表}))]

表这一列说的是答案，不是代换。在代换上，合取是目标的复合，前一个交出的代换交给后一个；在答案上，合取是两组条件都要满足，两张表按共有的列拼起来，没有共有的列就是每一行与每一行配对。析取在两层都是并。

@racket[succeed] 与 @racket[fail] 是@xref["05:relation"]{「关系」}一节的两个零元关系。那里说，零元关系只有两个：一个有一行 @racket[()]，一个一行也没有。在关系语言里，它们是不提任何未知项的条件，一个总成立，一个总不成立；落到实现，是代换上的恒等关系与空关系，合取与析取的单位。

最后一行要打个折扣。@racket[run*] 交出的是一张答案的列表，有先后，可能重复，答案里还可能有 @tt{_.0} 这样的名字。答案都是具体的值、搜索走完、去掉重复以后，它才是那张表。

@section[#:tag "05:microkanren"]{这门语言的名字}

只有等式、合取、析取、存在和两个单位，这门小语言的骨架就是 microKanren：逻辑式编程语言 miniKanren 的一个极小的内核。常见的实现用流来回溯：目标交出一串代换，合取与析取要自己写出怎样接、怎样并。这里用 @racket[amb] 回溯，合取就是 ℬ 的复合，析取就是 @racket[amb]，这两样都是现成的；剩下要写的，主要是合一。和常见的实现相比，还有几处不同：未知项按身份区分，不编号；何时推迟一步计算、怎样取用答案，写法也不一样，交出答案的顺序因此可能不同。

整个实现收在附录里，不到一百行。
