#lang typed/racket/no-check

(provide (all-defined-out))

(: ∘ (∀ (p ...) (→ (→ pn-1 pn) ... (→ p1 p2) (→ p1 pn))))
(define ∘ compose)
(define id (∘))
(define (list->values v*) (apply values v*))

(define-type (← q p) (→ p q))
(: ⨾ (∀ (p ...) (→ (← pn-1 pn) ... (← p1 p2) (← p1 pn))))
(define (⨾ . f*) (apply ∘ (reverse f*)))


;;; 类型别名

(define-type ⊥ (∪))
(define-type (¬  a) (→ a ⊥))
(define-type (¬¬ a) (¬ (¬ a)))


;;; 答案类型（通过 raise 实现终结延续）

(struct (r) ans ([a* : (Listof r)]) #:type-name Ans)
(: a->⊥ (∀ (a) (¬ a)))
(define (a->⊥ . a*) (raise (ans a*)))
(define-syntax-rule (⊥->a exp)
  (with-handlers ([ans? (∘ list->values ans-a*)]) exp))


;;; 宿主的箭头

(define-type (→𝒟 p q) (→ p q))
(define-type (→𝒞 p q) (→ p q))

(: inj (∀ (p q) (→ (→𝒟 p q) (→𝒞 p q))))
(define (inj f) f)

;;; 逆否箭头

(define-type (→𝒰 p q) (← (¬ p) (¬ q)))
(define-type (¬𝒰 p)   (→𝒰 p ⊥))

(: neg (∀ (p q) (case→ (→ (→𝒞 p q) (→𝒰 p q))
                       (→ (→𝒰 p q) (→𝒟 (¬¬ p) (¬¬ q))))))
(define ((neg f) kq) (∘ kq f))


;;; CPS 箭头

(define-type (→𝒦 p q) (→ p (¬¬ q)))
(define-type (¬𝒦 p)   (→𝒦 p ⊥))

(: flip (∀ (p q) (case→ (→ (→𝒰 p q) (→𝒦 p q))
                        (→ (→𝒦 p q) (→𝒰 p q)))))
(define (((flip f) . y*) . x*) (apply (apply f x*) y*))

(: cps (∀ (p q) (→ (→𝒞 p q) (→𝒦 p q))))
(define cps (∘ flip neg))

(: cps:id (∀ (q) (→𝒦 q q)))
(define cps:id (cps id))


;;; anf: 宏

(define-syntax anf:let*-values
  (syntax-rules ()
    [(_ () b* ...)
     (anf:begin b* ...)]
    [(_ ([v* e]) b* ...)
     (λ (k) (e (λ v* ((anf:begin b* ...) k))))]
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

(define-syntax-rule (anf:let ([v e]) b* ...)
  (anf:let* ([v e]) b* ...))

(define-syntax-rule (anf:if test conseq alt)
  (λ (k) (test (λ b* ((if (equal? b* '(#f)) alt conseq) k)))))

(define-syntax-rule (anf:let/cc cps:k b* ...)
  (cps:call/cc (λ (cps:k) b* ...)))


;;; 两种箭头的复合

(: ∘𝒦 (∀ (p1 p2 p3) (→ (→𝒦 p2 p3) (→𝒦 p1 p2) (→𝒦 p1 p3))))
(define ((∘𝒦 cps:g cps:f) x)
  (anf:let ([y (cps:f x)])
    (cps:g y)))

(: ∘𝒰 (∀ (p1 p2 p3) (→ (→𝒰 p2 p3) (→𝒰 p1 p2) (→𝒰 p1 p3))))
(define ∘𝒰 ⨾)

(: neg:id (∀ (q) (→𝒰 q q)))
(define neg:id id)


;;; Clavius 律

(: neg:call/cc  (∀ (p) (→𝒰 (→𝒰 (¬𝒰 p) p) p)))
(: cps:call/cc  (∀ (p) (→𝒦 (→𝒦 (¬𝒦 p) p) p)))

(define ((neg:call/cc kp) neg:proc) ((neg:proc kp) (neg kp)))
(define ((cps:call/cc cps:proc) kp) ((cps:proc (cps kp)) kp))



;;; 填上延续参数

(: anf:eval (∀ (a) (→ (¬¬ a) a)))
(define (anf:eval kka) (⊥->a (kka a->⊥)))

(: uncps (∀ (p q) (→ (→𝒦 p q) (→𝒞 p q))))
(define (uncps cps:f) (∘ call/cc cps:f))

(: unneg (∀ (p q) (→ (→𝒰 p q) (→𝒞 p q))))
(define unneg (∘ uncps flip))


;;; 再用一次 neg

(: neg² (∀ (p q) (→ (→𝒞 p q) (→𝒟 (¬¬ p) (¬¬ q)))))
(define neg² (∘ neg neg))


;;; 否定翻译

(: neg²:id (∀ (a) (→𝒦 (¬¬ a) a)))
(define (neg²:id kka) kka)

(: neg²:call/cc (∀ (a) (→𝒟 (¬¬ (¬¬ a)) (¬¬ a))))
(define ((neg²:call/cc kkkka) ka) (kkkka (λ (kka) (kka ka))))


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
  ;; 「求值顺序与 ANF」：⨾ 照算的顺序写，和 let*、∘ 一致；(⨾) 也是 id。
  (let ([f add1] [g (λ (y) (* y 2))] [h number->string])
    (check-equal? ((⨾ f g h) 3) ((∘ h g f) 3))
    (check-equal? (let* ([y (f 3)] [z (g y)]) (h z)) ((⨾ f g h) 3))
    (check-equal? ((⨾) 5) 5))
  ;; 「提前返回」：改写前的宿主版本，用宿主的 let/cc；不进完整代码参考。
  (: mul (→ Real * Real))
  (define (mul . r*)
    (let/cc return
      (: loop (→ (Listof Real) Real))
      (define (loop r*)
        (if (null? r*)
            (*)
            (let* ([r (car r*)])
              (if (zero? r)
                  (return r)
                  (let* ([r* (cdr r*)]
                         [res (loop r*)])
                    (* res r))))))
      (loop r*)))
  (check-equal? (mul 1 2 3 4) 24)
  (check-equal? (mul 1 2 0 3 4) 0)
  ;; 「嵌入语言」的例子：cps:mul 是一支 𝒦 的箭头，不进完整代码参考。
  (: cps:mul (→ Real * (¬¬ Real)))
  (define (cps:mul . r*)
    (anf:let/cc cps:return
      (: cps:loop (→ (Listof Real) (¬¬ Real)))
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
  ;; 「手中的延续」：手写延续的版本。
  (let ([cps:proc1 (λ (cps:k) ((cps *) 2 3))]
        [cps:proc2 (λ (cps:k) (λ (k) ((cps:k 10) (λ (v) (k (add1 v))))))])
    (check-equal? (⊥->a ((cps:call/cc cps:proc1) (λ (v) (a->⊥ (add1 v))))) 7)
    (check-equal? (⊥->a ((cps:call/cc cps:proc2) (λ (v) (a->⊥ (add1 v))))) 11))
  ;; 练习：neg:call/cc 的手写版。
  (let ([neg:proc1 (λ (kp) (λ (neg:k) (((neg *) kp) 2 3)))]
        [neg:proc2 (λ (kp) (λ (neg:k) ((neg:k ((neg add1) kp)) 10)))])
    (check-equal? (⊥->a ((neg:call/cc ((neg add1) a->⊥)) neg:proc1)) 7)
    (check-equal? (⊥->a ((neg:call/cc ((neg add1) a->⊥)) neg:proc2)) 11))
  ;; 「绑定就是复合」：两种嵌套、两条单位律（合法 CPS 箭头）；∘𝒦 与借道 ⨾ 的定义相同。
  (let* ([cps:f (cps add1)] [cps:g (cps (λ (y) (* y 2)))] [cps:h (cps number->string)]
         [via-⨾ (λ (cps:g cps:f) (flip (⨾ (flip cps:g) (flip cps:f))))])
    (check-equal? (((∘𝒦 cps:h (∘𝒦 cps:g cps:f)) 3) values) (((∘𝒦 (∘𝒦 cps:h cps:g) cps:f) 3) values))
    (check-equal? ((anf:let ([y (cps:f 3)]) (anf:let ([z (cps:g y)]) (cps:h z))) values)
                  ((anf:let ([z (anf:let ([y (cps:f 3)]) (cps:g y))]) (cps:h z)) values))
    (check-equal? (((∘𝒦 cps:f cps:id) 3) values) ((cps:f 3) values))
    (check-equal? (((∘𝒦 cps:id cps:f) 3) values) ((cps:f 3) values))
    (check-equal? (((∘𝒦 cps:g cps:f) 3) values) (((via-⨾ cps:g cps:f) 3) values))
    ;; 普通纯函数提升保持复合。
    (check-equal? (((∘𝒦 cps:g cps:f) 3) values) (((cps (∘ (λ (y) (* y 2)) add1)) 3) values))
    ;; (flip id) 就是 cps:id。
    (check-equal? (((flip id) 5) values) ((cps:id 5) values)))
  ;; 宏不提前求值右边：构造时不打印，收到延续才打印；重复运行会重新求值。
  (let* ([out (open-output-string)]
         [kkv (parameterize ([current-output-port out])
                (anf:let ([v (begin (display "e" out) (cps:id 1))]) (cps:id v)))])
    (check-equal? (get-output-string out) "")
    (check-equal? (kkv values) 1)
    (check-equal? (kkv values) 1)
    (check-equal? (get-output-string out) "ee"))
  ;; 第一层就打印的箭头：单位律需要前提。
  (let* ([out (open-output-string)]
         [cps:noisy (λ (x) (display "!" out) (cps:id x))])
    ((∘𝒦 cps:noisy cps:id) 1)
    (check-equal? (get-output-string out) "")
    (cps:noisy 1)
    (check-equal? (get-output-string out) "!"))
  ;; neg²:id 收下一段计算，原样交出，不运行它。
  (let ([kk3 (cps:id 3)])
    (check-eq? (neg²:id kk3) kk3))
  ;; 「否定翻译」：(∘𝒦 neg²:id neg²:id) 只接掉外面一层，结果仍是计算。
  (let ([kkkka (cps:id (cps:id 7))])
    (check-equal? (((∘𝒦 neg²:id neg²:id) kkkka) values) 7))
  ;; 「箭头指向何方」：(uncps neg²:id) 就是 call/cc 的行为。
  (check-equal? (+ 1 ((uncps neg²:id) (λ (k) (k 41)))) 42)
  ;; 「两段计算怎样接起来」：(⨾ (neg g) (neg f)) 接两步。
  (let ([f add1] [g (λ (y) (* y 2))])
    (check-equal? (((⨾ (neg g) (neg f)) values) 3) (g (f 3))))
  ;; 练习：两个例子在 𝒰 里用 neg:call/cc 再跑一遍。
  (let* ([neg:add1  (neg add1)]
         [neg:proc1 (λ (kp) (λ (neg:k) (((neg *) kp) 2 3)))]
         [neg:proc2 (λ (kp) (λ (neg:k) (((∘𝒰 neg:add1 neg:k) kp) 10)))])
    (check-equal? (⊥->a (((∘𝒰 neg:add1 neg:call/cc) a->⊥) neg:proc1)) 7)
    (check-equal? (⊥->a (((∘𝒰 neg:add1 neg:call/cc) a->⊥) neg:proc2)) 11))
  ;; neg:call/cc：先收延续 kp，再收 neg:proc；调用 (neg kp) 也改走 kp。
  (check-equal? (⊥->a ((neg:call/cc (∘ a->⊥ add1)) (λ (kp) (λ (neg:k) (kp 99))))) 100)
  (check-equal? (⊥->a ((neg:call/cc (∘ a->⊥ add1)) (λ (kp) (λ (neg:k) ((neg:k id) 10) (kp 99))))) 11)
  ;; 「再次隐藏延续」开头：两步的手写 CPS 与 anf:let 都是 2；三步两种分组的 ∘𝒦 都是 6。
  (let ([cps:mul1 (cps (λ (v) (* 1 v)))]
        [cps:mul2 (cps (λ (v) (* 2 v)))]
        [cps:mul3 (cps (λ (v) (* 3 v)))])
    (check-equal? ((λ (k) ((cps:mul1 1) (λ (v1) ((cps:mul2 v1) (λ (v2) ((cps:mul3 v2) k)))))) values) 6)
    (check-equal? ((λ (k) ((cps:mul1 1) (λ (v) ((cps:mul2 v) k)))) values) 2)
    (check-equal? ((anf:let ([v (cps:mul1 1)]) (cps:mul2 v)) values) 2)
    (check-equal? ((anf:let ([v1 (cps:mul1 1)]) (anf:let ([v2 (cps:mul2 v1)]) (cps:mul3 v2))) values) 6)
    (check-equal? (((∘𝒦 cps:mul3 (∘𝒦 cps:mul2 cps:mul1)) 1) values) 6)
    (check-equal? (((∘𝒦 (∘𝒦 cps:mul3 cps:mul2) cps:mul1) 1) values) 6))
  ;; 含控制的箭头：两种分组安排同样的剩余工作。
  (let* ([cps:kv (λ (v) (anf:let/cc k (anf:if (cps:zero? v) (k 100) (cps:* v 10))))]
         [cps:f (cps add1)])
    (for ([x '(-1 4)])
      (check-equal? (anf:eval ((∘𝒦 cps:f (∘𝒦 cps:kv cps:f)) x))
                    (anf:eval ((∘𝒦 (∘𝒦 cps:f cps:kv) cps:f) x)))))
  ;; 「填上延续参数」：anf:eval 用 raise 与 handler 把答案交回调用处。
  (check-equal? (+ 1 (anf:eval (cps:mul 1 2 3 4))) 25)
  (check-equal? (+ 1 (anf:eval (cps:mul 1 2 0 3 4))) 1)
  ;; uncps 交入当前延续，两条路都回到调用处。
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
    "@\n*@\n**@\n***@"))
  ;; 正文的写法：打印也写成绑定。
  (check-true
   (output-starts-with?
    (λ ()
      (anf:eval
       (anf:let* ([cps:yin  (cps:label)]
                  [_        (cps:displayln #\@)]
                  [cps:yang (cps:label)]
                  [_        (cps:display #\*)])
         (cps:yin cps:yang))))
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
  ;; 「新箭头下的 Clavius 律」：回顾第一篇 call/cc 的类型，用 𝒞 的写法。
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

;; 「两种箭头」：两边的复合借 flip 互相定义（练习答案）。
(module* transport #f
  (require rackunit)
  (define (∘𝒰 neg:g neg:f)
    (flip
     (∘𝒦 (flip neg:g)
           (flip neg:f))))
  (define neg:f (neg add1))
  (define neg:g (neg (λ (y) (* y 2))))
  (check-equal? (((∘𝒰 neg:g neg:f) values) 3) ((neg:f (neg:g values)) 3))
  (check-equal? (((∘𝒰 neg:g neg:f) values) 3) (((⨾ neg:g neg:f) values) 3))
  (let ()
    (define (∘𝒦 cps:g cps:f)
      (flip
       (⨾ (flip cps:g)
           (flip cps:f))))
    (define cps:f (cps add1))
    (define cps:g (cps (λ (y) (* y 2))))
    (check-equal? (((∘𝒦 cps:g cps:f) 3) values) ((cps:g 4) values))))

;; 正文「嵌入语言」给出的简化版宏：单个函数体、单值；完整代码里的宏另外处理多值与多个表达式。
(module* simple-macros #f
  (require rackunit "../../tools/check-output-prefix.rkt")
  (define-syntax-rule (anf:let ([v e]) b)
    (λ (k) (e (λ (v) (b k)))))
  (define-syntax anf:let*
    (syntax-rules ()
      [(_ () b) b]
      [(_ ([v e] [v* e*] ...) b)
       (anf:let ([v e]) (anf:let* ([v* e*] ...) b))]))
  (define-syntax-rule (anf:let/cc cps:k b* ...)
    (cps:call/cc (λ (cps:k) b* ...)))
  (define-syntax anf:begin
    (syntax-rules ()
      [(_ b) b]
      [(_ e b* ...) (anf:let ([_ e]) (anf:begin b* ...))]))
  ;; 单值的 anf:if。
  (define-syntax-rule (anf:if test conseq alt)
    (λ (k) (test (λ (b) ((if b conseq alt) k)))))
  (check-equal? (⊥->a ((anf:let ([v (cps:+ 1 2)]) (cps:* v 3)) a->⊥)) 9)
  (define (∘𝒦 cps:g cps:f)
    (λ (x)
      (anf:let ([y (cps:f x)])
        (cps:g y))))
  (check-equal? (⊥->a (((∘𝒦 (cps add1) (cps add1)) 1) a->⊥)) 3)
  (define (cps:mul . r*)
    (anf:let/cc cps:return
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
  (check-equal? (anf:eval (cps:mul 1 2 3 4)) 24)
  (check-equal? (anf:eval (cps:mul 1 2 0 3 4)) 0)
  (define (cps:label) (cps:call/cc cps:id))
  (check-true
   (output-starts-with?
    (λ ()
      (anf:eval
       (anf:let* ([cps:yin (cps:label)])
         (anf:begin
           (cps:displayln #\@)
           (anf:let* ([cps:yang (cps:label)])
             (anf:begin
               (cps:display #\*)
               (cps:yin cps:yang)))))))
    "@\n*@\n**@\n***@")))

;; 「走一圈」「再用一次 neg」「否定翻译」：带 ≈ 的等式，用真正不返回的终结延续核对。
(module+ test
  (define cps:esc  ; 含控制：参数为负时经 cps:return 跳出
    (λ (x) (anf:let/cc cps:return
             (anf:if ((cps negative?) x) (cps:return 'neg) ((cps add1) x)))))
  (define (run kk) (⊥->a (kk a->⊥)))
  (for ([x '(-1 4)])
    ;; (cps (uncps cps:f)) ≈ cps:f
    (check-equal? (run ((cps (uncps cps:esc)) x)) (run (cps:esc x)))
    ;; (neg (uncps cps:f)) ≈ (flip cps:f)
    (check-equal? (⊥->a (((neg (uncps cps:esc)) a->⊥) x)) (⊥->a (((flip cps:esc) a->⊥) x)))
    ;; unneg 走 𝒦 回到 𝒞
    (check-equal? ((unneg (neg add1)) x) (add1 x)))
  ;; 关键规律：(ka (call/cc kka)) ≈ (kka ka)
  (let ([kka (λ (k) (k 5))] [kka2 (λ (k) (a->⊥ 'jump))])
    (check-equal? (⊥->a (a->⊥ (call/cc kka))) (⊥->a (kka a->⊥)))
    (check-equal? (⊥->a (a->⊥ (call/cc kka2))) (⊥->a (kka2 a->⊥))))
  ;; (neg² (uncps cps:f)) ≈ (neg (flip cps:f))
  (let ([kkx (cps:id 4)])
    (check-equal? (run ((neg² (uncps cps:esc)) kkx)) (run ((neg (flip cps:esc)) kkx))))
  ;; (neg² call/cc) ≈ neg²:call/cc ≈ (neg (flip neg²:id))；四重否定的 7
  (for ([kkkka (list (cps:id (cps:id 7))
                     (λ (k) (k (λ (ka) (ka 8))))
                     (λ (k) (a->⊥ 'skip)))])
    (check-equal? (run ((neg² call/cc) kkkka)) (run (neg²:call/cc kkkka)))
    (check-equal? (run ((neg (flip neg²:id)) kkkka)) (run (neg²:call/cc kkkka))))
  (check-equal? (anf:eval (neg²:call/cc (cps:id (cps:id 7)))) 7)
  ;; 同一支箭头：(cps call/cc) ≈ neg²:id，(neg call/cc) ≈ 用在 ¬a 上的 cps:id；
  ;; 数一数 k：neg²:call/cc 就是 (neg cps:id)，DNI 的逆否；¬³a → ¬a 也由 (neg cps:id) 给出。
  (for ([kka (list (cps:id 7) (λ (k) (k 8)) (λ (k) (a->⊥ 'skip)))])
    (check-equal? (run ((cps call/cc) kka)) (run (neg²:id kka)))
    (check-equal? (⊥->a (((neg call/cc) a->⊥) kka)) (⊥->a ((cps:id a->⊥) kka))))
  (for ([kkkka (list (cps:id (cps:id 7)) (λ (k) (k (λ (ka) (ka 8)))) (λ (k) (a->⊥ 9)))])
    (check-equal? (run ((neg cps:id) kkkka)) (run (neg²:call/cc kkkka))))
  (let ([kkka (λ (kka) (kka (λ (a) (a->⊥ (* a 10)))))])
    (check-equal? (⊥->a (((neg cps:id) kkka) 5)) 50))
  ;; (uncps neg²:id) 就是 call/cc
  (check-equal? (+ 1 ((uncps neg²:id) (λ (k) (k 41)))) 42))

(module+ test
  ;; 运行正文简化版宏与「两种箭头」的检查。
  (require (submod ".." simple-macros) (submod ".." transport)))

;; 「把延续独立出来」：flip 是自己的逆，条件是两层参数之间不做别的事。
(module+ test
  (let* ([out (open-output-string)]
         [quiet (λ (x) (λ (y) (+ x y)))]
         [noisy (λ (x) (display "!" out) (λ (y) (+ x y)))])
    (check-equal? (((flip (flip quiet)) 1) 2) ((quiet 1) 2))
    ((flip (flip noisy)) 1)
    (check-equal? (get-output-string out) "")
    (noisy 1)
    (check-equal? (get-output-string out) "!")))
