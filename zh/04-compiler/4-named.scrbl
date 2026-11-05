#lang acf/scribble

@title[#:tag "04:4-named"]{命名延续}

@racket[shift] 正是 @racket[ctx] 被拼接进生成代码的地方。在 @racket[if] 分支中，@racket[ctx] 出现在@emph{两个}子编译中：

@racketblock[
[`(if ,test ,conseq ,alt)
 (shift ctx
   (define t (anf0 test))
   `(if ,t ,(anf1 conseq ctx) ,(anf1 alt ctx)))]]

整个剩余上下文被复制进了每个分支。试着把一个 @racket[if] 放进一个更大的表达式：

@(define ev-dup (make-acf-eval))
@examples[#:eval ev-dup #:hidden
(require (submod acf/zh/04-compiler/code stage-20))]

@examples[#:eval ev-dup #:label #f
(anf '(f (if a b c)))]

对 @racket[f] 的调用出现在两个分支中。如果 @racket[if] 嵌套，每一层都把代码翻倍。指数膨胀。

但 @racket[if] 的两个分支都在尾位置：两个分支都不扩展@tech{延续}。@racket[if] 表达式的@tech{延续}@emph{就是}每个分支的@tech{延续}。如果我们把 @racket[ctx] 打印为一个 lambda，绑定到一个命名变量，让两个分支都应用那个名字，重复就消失了。

每个 @racket[if] 需要自己的@tech{延续}名字，嵌套的 @racket[if] 不能冲突。所以我们在 @racket[fv] 之外引入第二个生成器，产出 @racket[k.0]、@racket[k.1]、@racket[k.2] 这样的名字：

@racketblock[
(define fk (make-genvar 'k))

[`(if ,test ,conseq ,alt)
 (shift ctx
   (define vn (fv))
   (define kn (fk))
   (define t (anf0 test))
   `(let ([,kn (λ (,vn) ,(ctx vn))])
      (if ,t
          ,(anf1 conseq (λ (v) `(,kn ,v)))
          ,(anf1 alt    (λ (v) `(,kn ,v))))))]]

@racket[ctx] 被打印为 lambda 一次，绑定到 @racket[kn]。两个分支接收的上下文都是对 @racket[kn] 的调用。无论 @racket[if] 嵌套得多深，上下文都被共享而非复制，每一层都有自己的名字。

两个分支用了相同的上下文 @racket[(λ (v) `(,kn ,v))]。我们可以用定义 @racket[id] 的方式给它起个名字：正如 @racket[(λ (v) v)] 就是 @racket[(reset (shift k k))]，上下文 @racket[(λ (v) `(,kn ,v))] 就是 @racket[(reset `(,kn ,(shift k k)))]。用了这个命名后，@racket[if] 分支变成：

@racketblock[
[`(if ,test ,conseq ,alt)
 (shift ctx
   (define vn (fv))
   (define kn (fk))
   (define t (anf0 test))
   (define ctx0 (reset `(,kn ,(shift k k))))
   `(let ([,kn (λ (,vn) ,(ctx vn))])
      (if ,t ,(anf1 conseq ctx0) ,(anf1 alt ctx0))))]]

用之前让代码膨胀的那个例子测试：

@(define ev-named (make-acf-eval))
@examples[#:eval ev-named #:hidden
(require (submod acf/zh/04-compiler/code stage-named))]

@examples[#:eval ev-named #:label #f
(anf '(f (if a b c)))]

对 @racket[f] 的调用只出现一次，在绑定到 @racket[k.0] 的 lambda 内部。两个分支都调用 @racket[k.0]，而不是复制上下文。嵌套 @racket[if] 不再导致指数膨胀。

文法演化了。@racket[<if>] 产生式获得了一个新选项，@racket[<anf>] 获得了一个@tech{延续}调用：

@out-block|{
<anf> ::= <val> | <if> | (let ([<var> <atom>]) <anf>) | (<k> <val> ...)

<atom> ::= <val> | (<var> <val> ...)
<val>  ::= <var> | <literal> | <proc>

<if>     ::= <anf-if> | (let ([<k> <proc>]) <anf-if>)
<anf-if> ::= (if <val> <anf> <anf>)
<k>      ::= <var>

<proc> ::= (λ <head> <anf>)

<head>  ::= <var> | (<var> ...) | (<var> ... . <var>)
}|

@racket[<if>] 产生式现在有两种形式：裸的，和包在一个 @racket[let] 中、绑定了一个@tech{延续}的。@racket[let] 形式就是@defterm[#:en "named continuation"]{命名延续}：把编译时的上下文具体化为运行时的 lambda，然后通过名字引用它。@racket[<k>] 就是这样绑定的@tech{延续}变量。

到目前为止，源程序里没有 @racket[reset]，也没有 @racket[shift]，它们只出现在编译器自己的代码里。要是源语言里也有它们，编译器还能照样把剩余工作打印出来吗？
