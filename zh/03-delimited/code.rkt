#lang typed/racket/no-check

(provide (all-defined-out))

(: ∘ (∀ (p ...) (→ (→ pn-1 pn) ... (→ p1 p2) (→ p1 pn))))
(define ∘ compose)
(define id (∘))

(define-type (← q p) (→ p q))
(: ⨾ (∀ (p ...) (→ (← p2 p1) ... (← pn pn-1) (← pn p1))))
(define (⨾ . f*) (apply ∘ (reverse f*)))


;;; 局部否定（平凡表示）
;; a、x 是答案类型参数；类型标注只作设计说明，不经类型检查

(define-type ⊥ (∪))
(define-type ⊥ᵃ a)                            ; 局部空：平凡表示下就是 a
(define-type (¬ₐ p ...) (→ p ... ⊥ᵃ))
(define-type (¬ₐ¬ₐ p) (¬ₐ (¬ₐ p)))
(define-type (¬ₐ¬ₐ¬ₐ p) (¬ₐ (¬ₐ¬ₐ p)))
;; 下标换成 x（¬ₓ、¬ₓ¬ₓ、→𝒰ₓ……），就是以 x 为基的同一组类型

(: a->⊥ᵃ (∀ (a) (¬ₐ a)))
(define a->⊥ᵃ id)


;;; 宿主的箭头

(define-type (→𝒟 p ... q) (→ p ... q))


;;; 以 a 为基的两种箭头
;; ¬ 的下标是落点，箭头的下标是基；¬ 后面没有下标就落在全局的 ⊥ 上

(define-type (→𝒰ₐ p ... q) (← (¬ₐ p ...) (¬ₐ q)))
(define-type (→𝒦ₐ p ... q) (→ p ... (¬ₐ¬ₐ q)))

(define-type (¬ₐ𝒰ₓ p ...) (→𝒰ₓ p ... ⊥ᵃ))
(define-type (¬ₐ𝒦ₓ p ...) (→𝒦ₓ p ... ⊥ᵃ))
(define-type (¬𝒰ₐ  p ...) (→𝒰ₐ p ... ⊥))
(define-type (¬𝒦ₐ  p ...) (→𝒦ₐ p ... ⊥))

(: neg (∀ (p q a x) (case→ (→ (→𝒟 p q) (→𝒰ₓ  p q))
                           (→ (¬ₐ  p)  (¬ₐ𝒰ₓ p)))))
(define ((neg f) kq) (∘ kq f))

(: neg* (∀ (p a) (→ (¬ₐ p) (¬𝒰ₐ p))))
(define ((neg* kₐp) _k) kₐp)

(: flip (∀ (p q) (case→ (→ (→𝒰ₐ p q) (→𝒦ₐ p q))
                        (→ (→𝒦ₐ p q) (→𝒰ₐ p q)))))
(define (((flip f) . y*) . x*) (apply (apply f x*) y*))

(: cps  (∀ (p q a x) (case→ (→ (→𝒟 p q) (→𝒦ₓ  p q))
                            (→ (¬ₐ  p)  (¬ₐ𝒦ₓ p)))))
(: cps* (∀ (p a) (→ (¬ₐ p) (¬𝒦ₐ p))))
(define cps  (∘ flip neg))
(define cps* (∘ flip neg*))


;;; 控制运算符

(: neg:call/lc (∀ (p a) (→𝒰ₐ (→𝒰ₐ (¬ₐ𝒰ₐ p) p) p)))
(define ((neg:call/lc kₐp) neg:proc) ((neg:proc kₐp) (neg kₐp)))

(: neg:call/cc (∀ (p a) (→𝒰ₐ (→𝒰ₐ (¬𝒰ₐ p) p) p)))
(define ((neg:call/cc kₐp) neg:proc) ((neg:proc kₐp) (neg* kₐp)))

(: cps:call/lc (∀ (p a) (→𝒦ₐ (→𝒦ₐ (¬ₐ𝒦ₐ p) p) p)))
(: cps:call/cc (∀ (p a) (→𝒦ₐ (→𝒦ₐ (¬𝒦ₐ  p) p) p)))

(define ((cps:call/lc cps:proc) kₐp) ((cps:proc (cps  kₐp)) kₐp))
(define ((cps:call/cc cps:proc) kₐp) ((cps:proc (cps* kₐp)) kₐp))


;;; 求值与边界

(: cps:id (∀ (p a) (→𝒦ₐ p p)))
(define cps:id (cps id))

(: anf:eval (∀ (a) (¬ₐ¬ₐ¬ₐ a)))
(define anf:eval (cps:id a->⊥ᵃ))

(: anf:reset (∀ (a x) (→ (¬ₐ¬ₐ a) (¬ₓ¬ₓ a))))
(define anf:reset (cps anf:eval))

(define cps:abort (cps* a->⊥ᵃ))


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

(define-syntax-rule (anf:let/lc cps:k b* ...)
  (cps:call/lc (λ (cps:k) b* ...)))

(define-syntax-rule (anf:shift cps:k e)
  (anf:let/lc cps:k
    (anf:let* ([v e])
      (cps:abort v))))


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
  (require rackunit racket/control "../../tools/check-output-prefix.rkt")
  ;; 「四个例子」：同一条局部延续，不用、调用一次、调用两次。
  (define (example step)
    (anf:eval
     (anf:let* ([v (anf:reset
                    (anf:let* ([x (step)]
                               [y (cps:+ 2 x)])
                      (cps:abort y)))])
       (cps:+ 10 v))))
  (check-equal? (example (λ () (cps:id 3))) 15)
  (check-equal? (example (λ () (anf:shift cps:k (cps:id 3)))) 13)
  (check-equal? (example (λ () (anf:shift cps:k (cps:k 3)))) 15)
  (check-equal?
   (example (λ () (anf:shift cps:k
                  (anf:let* ([r (cps:k 3)]) (cps:k r)))))
   17)
  ;; 「两个 call/cc」：call/lc 交出的延续会返回，call/cc 交出的不会。
  (define (early call)
    (anf:eval
     (call
      (λ (cps:return)
        (define (cps:loop r*)
          (anf:if (cps:null? r*)
                  (cps:*)
                  (anf:let* ([r (cps:car r*)]
                             [r (anf:if (cps:zero? r) (cps:return r) (cps:id r))]
                             [r* (cps:cdr r*)]
                             [res (cps:loop r*)])
                    (cps:* res r))))
        (cps:loop '(1 2 0 3 4))))))
  (check-equal? (early cps:call/cc) 0)
  (check-equal? (early cps:call/lc) 0)
  ;; 「求值与边界」：anf:eval 交进 id；anf:reset 展开。
  (check-equal? (anf:eval (λ (k) (k 12))) 12)
  (check-equal? ((anf:reset (λ (k) (k 5))) add1) 6)
  ;; neg 两种写法、flip 来回一趟。
  (check-equal? (((neg add1) number->string) 4) "5")
  (check-equal? ((((flip (flip cps)) add1) 4) values) 5)
  ;; 「元延续」的阴阳谜题：let/lc 版输出不变。
  (define-syntax-rule (let/lc k body) (shift k (k body)))
  (check-true
   (output-starts-with?
    (λ ()
      (reset
       (let ([kn (let/lc k0 k0)])
         (displayln #\@)
         (let ([km (let/lc kn+1 kn+1)])
           (display #\*)
           (kn km)))))
    "@\n*@\n**@\n***@")))


;; 正文推导中的独立版本，同名定义各有自己的作用域。

;; 「函数调用」：一等标签版与假想的 return 版。
(module call racket
  (define (goto l) (l l))
  (define (label) (call/cc goto))
  (define (mul . r*)
    (define first? #t)
    (define result (*))
    (define ret (label))
    (when first?
      (set! first? #f)
      (for ([r (in-list r*)])
        (when (zero? r)
          (set! result r)
          (goto ret))
        (set! result (* result r))))
    result)
  (module* hypothetical racket
    ;; 正文假设的宿主 return：测试时用当前函数的退出延续实现。
    (provide (all-defined-out))
    (define current-return (make-parameter values))
    (define (return v) ((current-return) v))
    (define (mul . r*)
      (define result (*))
      (for ([r (in-list r*)])
        (when (zero? r) (return 0))
        (set! result (* result r)))
      (return result)))
  (provide (all-defined-out)))

;; 「返回答案」「边界的两侧」：结构体表示。
(module tagged typed/racket/no-check
  (provide (all-defined-out))
  (struct (r) ans ([a : r]) #:type-name Ans)
  (: mul (→ Real * Real))
  (define (mul . r*)
    (: real* (→ Real Real (∪ Real (Ans Real))))
    (define (real* a b)
      (if (or (zero? a) (zero? b))
          (ans 0)
          (* a b)))
    (: loop (→ (Listof Real) (∪ Real (Ans Real)) (Ans Real)))
    (define (loop r* result)
      (cond
        [(ans? result) result]
        [(null? r*) (ans result)]
        [else (loop (cdr r*) (real* (car r*) result))]))
    (ans-a (loop r* (*))))
  (define-type ⊥ᵃ (Ans Real))
  (define ⊥ᵃ?   ans?)
  (define a->⊥ᵃ ans)
  (define ⊥ᵃ->a ans-a)
  (define-type Realᵃ (∪ Real ⊥ᵃ)))

;; 「局部延续」「逃逸与丢弃」：结构体表示下的局部版本。
(module local typed/racket/no-check
  (provide (all-defined-out))
  (require (submod ".." tagged))
  (define-type (¬ₐ p ...) (→ p ... ⊥ᵃ))
  (: mul (→ Real * Real))
  (define (mul . r*)
    (: loop/kₐ (¬ₐ (Listof Real) (¬ₐ Real)))
    (define (loop/kₐ r* kₐ)
      (if (null? r*)
          (kₐ (*))
          (let ([r (car r*)])
            (if (zero? r)
                (a->⊥ᵃ r)
                (loop/kₐ (cdr r*) (λ (v) (kₐ (* v r))))))))
    (⊥ᵃ->a (loop/kₐ r* a->⊥ᵃ)))
  (define (((cps f) . p*) kₐq) (kₐq (apply f p*)))
  (define (anf:eval kₐkₐa) (⊥ᵃ->a (kₐkₐa a->⊥ᵃ)))
  (define (((cps* kₐp) . p*) _kₐq) (apply kₐp p*))
  (module* leaky #f
    (provide (all-defined-out))
    (define ((cps:call/cc cps:proc) kₐp) ((cps:proc (cps kₐp)) kₐp)))
  (module* fixed #f
    (provide (all-defined-out))
    (define ((cps:call/cc cps:proc) kₐp) ((cps:proc (cps* kₐp)) kₐp)))
  ;; 「边界中的边界」：结构体表示下手写 ⊥ᵃ->a 的 call/lc。
  (module* struct-lc #f
    (provide (all-defined-out))
    (define ((cps:call/lc cps:proc) kₐp)
      (define (kp p) (⊥ᵃ->a (kₐp p)))
      ((cps:proc (cps kp)) kₐp))))

;; 「边界中的边界」：平凡表示。
(module trivial typed/racket/no-check
  (provide (all-defined-out))
  (define id values)
  (define-type ⊥ᵃ Real)
  (define a->⊥ᵃ id)
  (define ⊥ᵃ->a id)
  (define (((cps f) . p*) kₐq) (kₐq (apply f p*)))
  (define ((cps:call/lc cps:proc) kₐp) ((cps:proc (cps kₐp)) kₐp))
  (define (anf:eval kₐkₐa) (⊥ᵃ->a (kₐkₐa a->⊥ᵃ)))
  (define anf:reset (cps anf:eval))
  ;; 「求值与边界」：anf:reset 展开以后。
  (module* expanded #f
    (provide (all-defined-out))
    (define ((anf:reset kₐkₐa) kₓa)
      (kₓa (anf:eval kₐkₐa)))))

;; 「从 return 到 shift」「规约规则」「元延续」：用 Racket 原生的 shift 写出的几种定义。
(module native racket
  (provide (all-defined-out))
  (require (rename-in (only-in racket/control reset shift) [shift primitive-shift]))
  (module* via-shift racket
    (provide (all-defined-out))
    (require racket/control)
    (define-syntax-rule (let/lc k body) (shift k (k body)))
    (define (abort . v*) (shift _ (apply values v*))))
  (define (abort . v*) (primitive-shift _ (apply values v*)))
  (define (call/lc proc) (primitive-shift k (k (proc k))))
  (define-syntax-rule (let/lc k body ...)
    (call/lc (λ (k) body ...)))
  (define-syntax-rule (shift k expr)
    (let/lc k (let ([v expr]) (abort v))))
  (define ∘ compose)
  (define (call/cc proc)
    (let/lc k (proc (∘ abort k)))))

;; 「局部否定下的箭头」：先给出的 anf:eval。
(module eval-first typed/racket/no-check
  (provide (all-defined-out))
  (define id values)
  (: a->⊥ᵃ (∀ (a) (¬ₐ a)))
  (define a->⊥ᵃ id)
  (: anf:eval (∀ (a) (→ (¬ₐ¬ₐ a) a)))
  (define (anf:eval kₐkₐa) (kₐkₐa a->⊥ᵃ)))

;; 「否定翻译与 A-翻译」：两条延续的 mul。
(module two typed/racket/no-check
  (provide (all-defined-out))
  (define id values)
  (define a->⊥ᵃ id)
  (: mul (→ Real * Real))
  (define (mul . r*)
    (: loop/ki (¬ₐ (Listof Real) (¬ₐ Real) (¬ₐ Real)))
    (define (loop/ki r* kₐ iₐ)
      (if (null? r*)
          (kₐ (*))
          (let ([r (car r*)])
            (if (zero? r)
                (iₐ r)
                (loop/ki (cdr r*) (λ (v) (kₐ (* v r))) iₐ)))))
    (loop/ki r* a->⊥ᵃ a->⊥ᵃ)))

;; 「用 call/cc 造定界延续」：元延续成了变量。
(module from-call-cc racket
  (provide (all-defined-out))
  (define meta-k exit)
  (define (abort . v*) (apply meta-k v*))
  (define (call/prompt thk)
    (define k0 meta-k)
    (let/cc k1
      (set! meta-k (λ v* (set! meta-k k0) (apply k1 v*)))
      (call-with-values thk abort)))
  (define-syntax-rule (reset b b* ...)
    (call/prompt (λ () b b* ...)))
  (define (call/lc proc)
    (let/cc k
      (define (local-k . v*)
        (reset (apply k v*)))
      (proc local-k)))
  (define-syntax-rule (shift k b b* ...)
    (call/lc (λ (k) (call-with-values (λ () b b* ...) abort)))))

(module+ test
  (require (prefix-in label: (submod ".." call))
           (prefix-in hypothetical: (submod ".." call hypothetical))
           (prefix-in tagged: (submod ".." tagged))
           (prefix-in local: (submod ".." local))
           (prefix-in leaky: (submod ".." local leaky))
           (prefix-in fixed: (submod ".." local fixed))
           (prefix-in struct: (submod ".." local struct-lc))
           (prefix-in trivial: (submod ".." trivial))
           (prefix-in expanded: (submod ".." trivial expanded))
           (prefix-in native: (submod ".." native))
           (prefix-in first: (submod ".." eval-first))
           (prefix-in two: (submod ".." two))
           (prefix-in cc: (submod ".." from-call-cc)))
  (for ([mul (list label:mul tagged:mul local:mul two:mul)])
    (check-equal? (mul 1 2 3 4) 24)
    (check-equal? (mul 1 2 0 3 4) 0))
  (check-equal?
   (call/cc (λ (k)
              (parameterize ([hypothetical:current-return k])
                (hypothetical:mul 2 0 4))))
   0)
  ;; 结构体表示下，(cps kₐp) 让答案漏给乘法；cps* 修好；手写 ⊥ᵃ->a 的 call/lc 也行。
  (define ((struct-early call) _)
    (local:anf:eval
     (call
      (λ (cps:return)
        (λ (k) (((local:cps *) 1 2) (λ (v) ((cps:return 0) (λ (w) (k (* v w)))))))))))
  (check-exn exn:fail:contract? (λ () ((struct-early leaky:cps:call/cc) #f)))
  (check-equal? ((struct-early fixed:cps:call/cc) #f) 0)
  (check-equal? ((struct-early struct:cps:call/lc) #f) 0)
  (check-equal? (trivial:anf:eval ((trivial:cps add1) 3)) 4)
  (check-equal? ((trivial:anf:reset (λ (k) (k 5))) add1) 6)
  (check-equal? ((expanded:anf:reset (λ (k) (k 5))) add1) 6)
  ;; 原生 shift 写出的定义，以及「元延续」的 105。
  (check-equal? (reset (native:shift k (k 3))) 3)
  (check-equal? (reset (native:call/cc (λ (k) (k 4)))) 4)
  (check-equal?
   (let ([k (reset (let ([x (native:call/cc (λ (k) (native:abort k)))]) (+ x 2)))])
     (+ (reset (k 3)) 100))
   105)
  (check-equal? (first:anf:eval (λ (k) (k 7))) 7)
  ;; 「用 call/cc 造定界延续」的四个例子。
  (check-equal? (let ([v (cc:reset (let* ([x 3] [y (+ 2 x)]) (cc:abort y)))]) (+ 10 v)) 15)
  (check-equal? (let ([v (cc:reset (let* ([x (cc:shift k 3)] [y (+ 2 x)]) (cc:abort y)))]) (+ 10 v)) 13)
  (check-equal? (let ([v (cc:reset (let* ([x (cc:shift k (k 3))] [y (+ 2 x)]) (cc:abort y)))]) (+ 10 v)) 15)
  (check-equal? (let ([v (cc:reset (let* ([x (cc:shift k (let ([r (k 3)]) (k r)))] [y (+ 2 x)]) (cc:abort y)))]) (+ 10 v)) 17))
