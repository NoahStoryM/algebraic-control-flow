#lang typed/racket/no-check

(provide (all-defined-out))

(define ∘ compose)
(define id (∘))
(define (list->values v*) (apply values v*))


;;; 类型别名

(define-type ⊥ (∪))
(define-type (¬  a) (→ a ⊥))
(define-type (¬¬ a) (¬ (¬ a)))
(define-type (← q p) (→ p q))


;;; 答案类型（通过 raise 实现终结延续）

(struct (r) ans ([a* : (Listof r)]) #:type-name Ans)
(: a->⊥ (∀ (a) (¬ a)))
(define (a->⊥ . a*) (raise (ans a*)))
(define-syntax-rule (⊥->a exp)
  (with-handlers ([ans? (∘ list->values ans-a*)]) exp))


;;; 宿主世界

(define-type (→𝒟 p q) (→ p q))
(define-type (→𝒞 p q) (→ p q))

(: inj (∀ (p q) (→ (→𝒟 p q) (→𝒞 p q))))
(define (inj f) f)

;;; 逆否世界

(define-type (→𝒰 p q) (← (¬ p) (¬ q)))
(define-type (¬𝒰 p)   (→𝒰 p ⊥))

(: neg (∀ (p q) (case→ (→ (→𝒞 p q) (→𝒰 p q))
                       (→ (→𝒰 p q) (→ (¬¬ p) (¬¬ q))))))
(define ((neg f) kq) (∘ kq f))

(: ⨾ (∀ (p ...) (→ (← pn-1 pn) ... (← p1 p2) (← p1 pn))))
(define (⨾ . f*) (apply ∘ (reverse f*)))

(: ∘𝒰 (∀ (p ...) (→ (→𝒰 pn-1 pn) ... (→𝒰 p1 p2) (→𝒰 p1 pn))))
(define ∘𝒰 ⨾)

(: neg:id (∀ (q) (→𝒰 q q)))
(define neg:id (∘𝒰))


;;; CPS 世界

(define-type (→𝒦 p q) (→ p (¬¬ q)))
(define-type (¬𝒦 p)   (→𝒦 p ⊥))

(: flip (∀ (p q) (case→ (→ (→𝒰 p q) (→𝒦 p q))
                        (→ (→𝒦 p q) (→𝒰 p q)))))
(define (((flip f) . y*) . x*) (apply (apply f x*) y*))

(: cps (∀ (p q) (→ (→𝒞 p q) (→𝒦 p q))))
(define cps (∘ flip neg))

(: ∘𝒦 (∀ (p ...) (→ (→𝒦 pn-1 pn) ... (→𝒦 p1 p2) (→𝒦 p1 pn))))
(define (∘𝒦 . cps:f*) (flip (apply ∘𝒰 (map flip cps:f*))))

(: cps:id (∀ (q) (→𝒦 q q)))
(define cps:id (∘𝒦))


;;; Clavius 律

(: neg:call/cc  (∀ (p) (→𝒰 (→𝒰 (¬𝒰 p) p) p)))
(: cps:call/cc  (∀ (p) (→𝒦 (→𝒦 (¬𝒦 p) p) p)))

(define ((neg:call/cc kp) neg:proc) ((neg:proc kp) (neg kp)))
(define ((cps:call/cc cps:proc) kp) ((cps:proc (cps kp)) kp))


;;; 两次逆否

(: neg² (∀ (p q) (→ (→𝒟 p q) (→𝒟 (¬¬ p) (¬¬ q)))))
(define neg² (∘ neg neg))


;;; anf: 宏

(define-syntax anf:let*-values
  (syntax-rules ()
    [(_ () b* ...)
     (anf:begin b* ...)]
    [(_ ([v* e]) b* ...)
     (let ([kkv e])
       (: neg²:id  (→𝒦 (¬¬ a) a))
       (: cps:kv   (→𝒦     a  b))
       (: cps:kkkv (→𝒦 (¬¬ a) b))
       (define (neg²:id kkv) kkv)
       (define (cps:kv . v*) (anf:begin b* ...))
       (define cps:kkkv (∘𝒦 cps:kv neg²:id))
       (cps:kkkv kkv))]
    [(_ ([v* e] [v** e*] ...) b* ...)
     (anf:let*-values ([v* e])
       (anf:let*-values ([v** e*] ...)
         b* ...))]))

(define-syntax anf:begin
  (syntax-rules ()
    [(_ b) b]
    [(_ b b* ...) (anf:let*-values ([_ b]) b* ...)]))

(define-syntax-rule (anf:let* ([v e] ...) b* ...)
  (anf:let*-values ([(v) e] ...) b* ...))

(define-syntax-rule (anf:if test conseq alt)
  (let ([kkb test])
    (: neg²:id  (→𝒦 (¬¬ Boolean) Boolean))
    (: cps:kb   (→𝒦     Boolean  a))
    (: cps:kkkb (→𝒦 (¬¬ Boolean) a))
    (define (neg²:id kkb) kkb)
    (define (cps:kb . b*) (if (equal? b* '(#f)) alt conseq))
    (define cps:kkkb (∘𝒦 cps:kb neg²:id))
    (cps:kkkb kkb)))

(define-syntax-rule (anf:let/cc cps:k b* ...)
  (cps:call/cc (λ (cps:k) b* ...)))


;;; 填上延续参数

(: anf:eval (∀ (a) (→ (¬¬ a) a)))
(define (anf:eval kka) (⊥->a (kka a->⊥)))

(: uncps (∀ (p q) (→ (→𝒦 p q) (→𝒞 p q))))
(define (uncps cps:f) (∘ call/cc cps:f))


;;; CPS 提升的基本操作

(define cps:+         (cps +))
(define cps:*         (cps *))
(define cps:zero?     (cps zero?))
(define cps:car       (cps car))
(define cps:cdr       (cps cdr))
(define cps:null?     (cps null?))
(define cps:display   (cps display))
(define cps:displayln (cps displayln))


(module+ test
  (require rackunit "../../tools/check-output-prefix.rkt")
  ;; 「嵌入语言」的例子：cps:mul 是一支 𝒦 的箭头，不进完整代码参考。
  (: cps:mul (→ Real * (¬¬ Real)))
  (define (cps:mul . r*)
    (anf:let/cc cps:return
      (: cps:loop (→𝒦 (Listof Real) Real))
      (define (cps:loop r*)
        (anf:if (cps:null? r*)
                (cps:*)
                (anf:let* ([r (cps:car r*)])
                  (anf:if (cps:zero? r)
                          (cps:return r)
                          (anf:let* ([r* (cps:cdr r*)]
                                     [res (cps:loop r*)])
                            (cps:* res r))))))
      (cps:loop r*)))
  ;; 普通箭头经 CPS 提升后交给答案通道；组合不应改变结果。
  (check-equal? (anf:eval ((cps +) 2 3)) 5)
  (check-equal? (anf:eval ((∘𝒦 (cps add1) (cps (λ (x) (* 2 x)))) 3)) 7)
  (check-equal? (anf:eval
                 (cps:call/cc
                  (λ (return) (return 42))))
                42)
  (check-equal? (⊥->a ((λ () (a->⊥ 9)))) 9)
  (check-equal?
   (anf:eval
    (anf:let/cc cps:return
      (anf:let* ([r (cps:id 0)])
        (cps:return r))))
   0)
  ;; 「嵌入语言」：cps:mul 是 𝒦 的箭头，遇零经 cps:return 跳出。
  (check-equal? (anf:eval (cps:mul 1 2 3 4)) 24)
  (check-equal? (anf:eval (cps:mul 1 2 0 3 4)) 0)
  ;; 「手中的延续」的运行例：正常交回，与调用交出去的延续后改走 kp。
  (let* ([cps:add1 (cps add1)]
         [cps:proc1 (λ (cps:k) ((cps *) 2 3))]
         [cps:proc2 (λ (cps:k) ((∘𝒦 cps:add1 cps:k) 10))])
    (check-equal? (⊥->a (((∘𝒦 cps:add1 cps:call/cc) cps:proc1) a->⊥)) 7)
    (check-equal? (⊥->a (((∘𝒦 cps:add1 cps:call/cc) cps:proc2) a->⊥)) 11))
  ;; neg:call/cc：先收延续 kp，再收 neg:proc；调用 (neg kp) 也改走 kp。
  (check-equal? (⊥->a ((neg:call/cc (∘ a->⊥ add1)) (λ (kp) (λ (neg:k) (kp 99))))) 100)
  (check-equal? (⊥->a ((neg:call/cc (∘ a->⊥ add1)) (λ (kp) (λ (neg:k) ((neg:k id) 10) (kp 99))))) 11)
  ;; 「再次隐藏延续」开头：手写 CPS、∘𝒦 复合、anf:let 三种写法算出同一个结果。
  (let ([cps:mul3 (cps (λ (v) (* 3 v)))])
    (check-equal? ((λ (k) ((cps:+ 1 2) (λ (v) ((cps:* v 3) k)))) values) 9)
    (check-equal? (((∘𝒦 cps:mul3 cps:+) 1 2) values) 9)
    (check-equal? (anf:eval (anf:let* ([v (cps:+ 1 2)]) (cps:* v 3))) 9))
  ;; 「再次隐藏延续」：(neg² id) 什么也不做，就是宏里的 neg²:id。
  (let* ([neg²:id (neg² id)]
         [macro:id (λ (kkv) kkv)]
         [cps:mul3 (cps (λ (v) (* v 3)))]
         [cps:g (cps (λ (v) (+ v 1)))])
    (check-equal? (anf:eval ((neg² id) (cps:+ 1 2))) 3)
    (check-equal? (anf:eval ((∘𝒦 cps:mul3 neg²:id) (cps:+ 1 2)))
                  (anf:eval ((∘𝒦 cps:mul3 macro:id) (cps:+ 1 2))))
    (check-equal? (anf:eval ((∘𝒦 cps:mul3 neg²:id) (cps:+ 1 2))) 9)
    ;; 拿掉 neg²:id：((∘𝒦 cps:kv neg²:id) (cps:g y)) = ((∘𝒦 cps:kv cps:g) y)
    (check-equal? (anf:eval ((∘𝒦 cps:mul3 neg²:id) (cps:g 4)))
                  (anf:eval ((∘𝒦 cps:mul3 cps:g) 4)))
    ;; 「否定翻译」：(∘𝒦 cps:kv neg²:id) = (neg (flip cps:kv))，含控制的 cps:kv 也成立。
    (define (cps:kv v) (anf:let/cc k (anf:if (cps:zero? v) (k 'zero) (cps:* v 10))))
    (for ([x '(0 4)])
      (check-equal? (anf:eval ((∘𝒦 cps:kv neg²:id) (cps:id x)))
                    (anf:eval ((neg (flip cps:kv)) (cps:id x)))))
    ;; 纯函数特例：(∘𝒦 (cps f) neg²:id) = (neg² f)
    (check-equal? (anf:eval ((∘𝒦 (cps add1) neg²:id) (cps:+ 1 2)))
                  (anf:eval ((neg² add1) (cps:+ 1 2)))))
  ;; 「填上延续参数」：uncps 交入当前延续，两条路都回到调用处。
  (check-equal? (+ 1 ((uncps cps:mul) 1 2 3 4)) 25)
  (check-equal? (+ 1 ((uncps cps:mul) 1 2 0 3 4)) 1)
  (check-equal? ((uncps (cps add1)) 41) 42)
  (define (cps:label) (cps:call/cc cps:id))
  (check-true
   (output-starts-with?
    (λ ()
      (anf:eval
       (anf:let* ([cps:yin (cps:label)])
         (cps:displayln #\@)
         (anf:let* ([cps:yang (cps:label)])
           (cps:display #\*)
           (cps:yin cps:yang)))))
    "@\n*@\n**@\n***@")))


;; 正文推导中的独立版本，同名定义各有自己的作用域。

(module stage-1 typed/racket/no-check

  (: fact (→ Natural Natural))

  (define (fact n)
    (if (= n 0)
        1
        (* n (fact (- n 1)))))

  (: fib (→ Natural Natural))

  (define (fib n)
    (if (< n 2)
        n
        (+ (fib (- n 1))
           (fib (- n 2)))))
  (provide (all-defined-out))
)

(module stage-2 typed/racket/no-check

  (: fact (→ Natural Natural))

  (define (fact n)
    (if (= n 0) 1
        (let* ([n-1 (- n 1)]
               [v   (fact n-1)])
          (* n v))))

  (: fib (→ Natural Natural))

  (define (fib n)
    (if (< n 2) n
        (let* ([n-1 (- n 1)]
               [v   (fib n-1)]
               [n-2 (- n 2)]
               [w   (fib n-2)])
          (+ v w))))
  (provide (all-defined-out))
)

(module stage-5 typed/racket/no-check
  (define-type ⊥ (∪))
  (define-type (¬ p) (→ p ⊥))
  (define-type (¬¬ p) (¬ (¬ p)))
  (: fact/k (→ Natural (¬ Natural) ⊥))

  (define (fact/k n k)
    (if (= n 0)
        (k 1)
        (fact/k (- n 1)
                (λ (v) (k (* n v))))))

  (: fib/k (→ Natural (¬ Natural) ⊥))

  (define (fib/k n k)
    (if (< n 2)
        (k n)
        (fib/k (- n 1)
               (λ (v)
                 (fib/k (- n 2)
                        (λ (w)
                          (k (+ v w))))))))
  (provide (all-defined-out))
)

(module stage-6 typed/racket/no-check

  (: fact (→ Natural Natural))

  (define (fact n)
    (let loop ([n n] [acc 1])
      (if (= n 0)
          acc
          (loop (- n 1) (* n acc)))))
  (provide (all-defined-out))
)

(module stage-7 typed/racket/no-check
  (define-type ⊥ (∪))
  (define-type (¬ p) (→ p ⊥))
  (define-type (¬¬ p) (¬ (¬ p)))
  (: fact/k (→ Natural (¬ Natural) ⊥))

  (define (fact/k n k)
    (let loop/k ([n n] [acc 1] [k k])
      (if (= n 0)
          (k acc)
          (loop/k (- n 1) (* n acc) k))))
  (provide (all-defined-out))
)

(module stage-9 typed/racket/no-check
  (provide ans? ans-a* a->⊥ list->values ⊥->a)
  (struct (r) ans ([a* : (Listof r)]) #:type-name Ans)
  (define (list->values v*) (apply values v*))
  (define (a->⊥ . a*) (raise (ans a*)))
  (define-syntax-rule (⊥->a exp)
    (with-handlers ([ans? (compose list->values ans-a*)]) exp))
  (provide (all-defined-out))
)

(module stage-11 typed/racket/no-check
  (define-type ⊥ (∪))
  (define-type (¬ p) (→ p ⊥))
  (define-type (¬¬ p) (¬ (¬ p)))
  (require (submod ".." stage-9))
  (: mul (→ Real * Real))

  (define (mul . r*)
    (: loop/k (→ (Listof Real) (→ Real ⊥) ⊥))
    (define (loop/k r* k)
      (if (null? r*)
          (k (*))
          (let ([r (car r*)])
            (if (zero? r)
                (a->⊥ r)
                (loop/k (cdr r*) (λ (v) (k (* v r))))))))
    (⊥->a (loop/k r* a->⊥)))
  (provide (all-defined-out))
)

(module stage-12 typed/racket/no-check

  (define (zero?/k x k) (k (zero? x)))
  (provide (all-defined-out))
)

(module stage-14 typed/racket/no-check

  (define (((neg f) kq) . p*) (kq (apply f p*)))

  (define (((cps f) . p*) kq) (kq (apply f p*)))
  (provide (all-defined-out))
)

(module stage-15 typed/racket/no-check
  (define-type ⊥ (∪))
  (define-type (¬ p) (→ p ⊥))
  (define-type (¬¬ p) (¬ (¬ p)))
  (define (((neg f) kq) . p*) (kq (apply f p*)))
  (define (((cps f) . p*) kq) (kq (apply f p*)))
  (: neg (∀ (p q) (→ (→ p q) (→ (¬ q) (¬ p)))))

  (: cps (∀ (p q) (→ (→ p q) (→    p (¬¬ q)))))
  (provide (all-defined-out))
)

(module stage-16 typed/racket/no-check
  (define (((flip f) . y*) . x*) (apply (apply f x*) y*))
  (: flip (∀ (x y z) (→ (→ x (→ y z)) (→ y (→ x z)))))
  (provide (all-defined-out))
)

(module stage-17 typed/racket/no-check
  (define-type ⊥ (∪))
  (define-type (¬ p) (→ p ⊥))
  (define-type (¬¬ p) (¬ (¬ p)))
  (define (((flip f) . y*) . x*) (apply (apply f x*) y*))
  (: flip (∀ (p q) (case→ (→ (→ (¬ q) (¬ p)) (→ p (¬¬ q)))
                          (→ (→ p (¬¬ q)) (→ (¬ q) (¬ p))))))
  (provide (all-defined-out))
)

(module stage-22 typed/racket/no-check
  (define-type ⊥ (∪))
  (define-type (¬ p) (→ p ⊥))
  (define-type (¬¬ p) (¬ (¬ p)))
  (define-type (→𝒰 p q) (→ (¬ q) (¬ p)))
  (provide (all-defined-out))
)

(module stage-clavius typed/racket/no-check
  ;; 「新世界下的 Clavius 律」：回顾第一篇 call/cc 的类型，用 𝒞 的写法。
  (define-type ⊥ (∪))
  (define-type (→𝒞 p q) (→ p q))
  (define-type (¬𝒞 p) (→𝒞 p ⊥))
  (: call/cc (∀ (p) (→𝒞 (→𝒞 (¬𝒞 p) p) p)))
)

(module+ test
  (require (prefix-in direct: (submod ".." stage-1))
           (prefix-in named: (submod ".." stage-2))
           (prefix-in recursive: (submod ".." stage-5))
           (prefix-in tail: (submod ".." stage-6))
           (prefix-in tail/k: (submod ".." stage-7))
           (prefix-in answer: (submod ".." stage-11))
           (prefix-in lift: (submod ".." stage-14)))
  (for ([fact (list direct:fact named:fact tail:fact)])
    (check-equal? (fact 6) 720))
  (for ([fib (list direct:fib named:fib)])
    (check-equal? (fib 10) 55))
  (check-equal? (recursive:fact/k 6 values) 720)
  (check-equal? (recursive:fib/k 10 values) 55)
  (check-equal? (tail/k:fact/k 6 values) 720)
  (check-equal? (answer:mul 2 3 4) 24)
  (check-equal? (answer:mul 2 0 4) 0)
  (check-equal? (((lift:cps add1) 7) values) 8))
