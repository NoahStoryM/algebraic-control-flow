#lang racket
;; 每次推导保留正文里的名字；循环定义放进不同子模块，各自选择底层原语。

(module label-to-cc racket
  (require (only-in racket/base [call/cc primitive-call/cc]))
  (provide label goto cc call/cc mul)
  (define (goto l) (l l))
  (define (label) (primitive-call/cc goto))

  (define (cc)
    (define saved #f)
    (define l (label))
    (if saved
        (apply values saved)
        (λ args (set! saved args) (goto l))))

  (define (call/cc proc)
    (define x (cc))
    (if (list? x)
        (apply values x)
        (proc (λ args (x args)))))

  (define (mul . r*)
    (define result (cc))
    (if (real? result)
        result
        (for/fold ([res (*)] #:result (result res))
                  ([r (in-list r*)])
          (if (zero? r)
              (result r)
              (* res r))))))

(module label-to-cc/return racket
  (require (only-in (submod ".." label-to-cc) call/cc))
  (provide mul)
  (define (mul . r*)
    (call/cc
     (λ (return)
       (for/fold ([res (*)])
                 ([r (in-list r*)])
         (if (zero? r)
             (return r)
             (* res r)))))))

(module call/cc-to-label racket
  (provide label goto)
  (define (goto l) (l l))
  (define (label) (call/cc goto)))

(module label-to-call/cc racket
  (require (only-in racket/base [call/cc primitive-call/cc]))
  (provide label goto cc call/cc)
  (define (goto l) (l l))
  (define (label) (primitive-call/cc goto))
  (define (call/cc proc)
    (define saved #f)
    (define l (label))
    (if saved
        (apply values saved)
        (proc (λ args (set! saved args) (goto l)))))
  (define (cc) (call/cc values)))

(module cc-to-label racket
  (require (only-in racket/base [call/cc primitive-call/cc]))
  (provide label goto)
  (define (cc) (primitive-call/cc values))
  (define (label) (cc))
  (define (goto l) (l l)))

(module+ test
  (require rackunit "../../tools/check-output-prefix.rkt"
           (prefix-in a: (submod ".." label-to-cc))
           (prefix-in b: (submod ".." call/cc-to-label))
           (prefix-in c: (submod ".." label-to-call/cc))
           (prefix-in d: (submod ".." cc-to-label))
           (prefix-in e: (submod ".." label-to-cc/return)))

  (define (count-to-seven label goto)
    (let ([x 0])
      (define loop (label))
      (set! x (add1 x))
      (when (< x 7) (goto loop))
      x))
  (for ([pair (list (cons a:label a:goto)
                   (cons b:label b:goto)
                   (cons c:label c:goto)
                   (cons d:label d:goto))])
    (check-equal? (count-to-seven (car pair) (cdr pair)) 7))

  (check-equal? (a:mul) 1)
  (check-equal? (a:mul 2 3 4) 24)
  (check-equal? (a:mul 2 3 0 4) 0)
  (check-equal? (e:mul) 1)
  (check-equal? (e:mul 2 3 4) 24)
  (check-equal? (e:mul 2 0 3) 0)
  (check-equal? (a:call/cc (λ (k) (+ 100 (k 9)))) 9)
  (check-equal? (c:call/cc (λ (k) (+ 100 (k 9)))) 9)
  (check-equal? (let ([v (a:cc)]) (if (procedure? v) (v 42) v)) 42)
  (check-equal? (let ([v (c:cc)]) (if (procedure? v) (v 42) v)) 42)
  (check-true
   (output-starts-with?
    (λ ()
      (let ([yin (a:label)])
        (displayln #\@)
        (let ([yang (a:label)])
          (display #\*)
          (yin yang))))
    "@\n*@\n**@\n***@")))


;; 正文推导中的独立版本，同名定义各有自己的作用域。

(module stage-1 typed/racket/no-check
  (define-type Label (→ Label ⊥))
  (define (goto l) (l l))
  (define (label) (call/cc goto))
  (define-type ⊥ (∪))

  (: goto  (→ Label ⊥))

  (: label (→ Label))
  (provide (all-defined-out))
)

(module stage-3 racket
  (define (goto l) (l l))
  (define (label) (call/cc goto))
  (define (mul . r*)
    (define first? #t)
    (define result (*))       ; 乘法单位元 = 1
    (define ret (label))
    (when first?
      (set! first? #f)
      (for ([r (in-list r*)])
        (when (zero? r)
          (set! result r)
          (goto ret))
        (set! result (* result r))))
    result)
  (provide (all-defined-out))
)

(module stage-4 typed/racket/no-check
  (define-type ⊥ (∪))
  (define-type Label (→ Label ⊥))
  (define (goto l) (l l))
  (define (label) (call/cc goto))
  (define (cc) (call/cc values))
  (: cc (∀ (p) (→ (∪ p (→ p ⊥)))))
  (provide (all-defined-out))
)

(module stage-6 typed/racket/no-check
  (define-type ⊥ (∪))
  (define-type Label (→ Label ⊥))
  (define (goto l) (l l))
  (define (label) (call/cc goto))
  (define (cc) (call/cc values))
  (define (call/cc proc) (let/cc k (proc k)))
  (: call/cc (∀ (p) (→ (→ (→ p ⊥) p) p)))
  (provide (all-defined-out))
)

(module stage-7 racket

  (define-syntax-rule (let/cc k body ...)
    (call/cc (λ (k) body ...)))
  (provide (all-defined-out))
)

(module stage-8 typed/racket/no-check
  (define-type ⊥ (∪))
  (: absurd (∀ (q) (→ ⊥ q)))

  (define absurd (case-λ))
  (provide (all-defined-out))
)

(module stage-10 typed/racket/no-check
  (define-type ⊥ (∪))
  (define-type Label (→ Label ⊥))
  (provide (all-defined-out))
)

(module stage-13 typed/racket/no-check
  (define-type ⊥ (∪))
  (define-type (¬ p) (→ p ⊥))
  (provide (all-defined-out))
)

(module stage-14 typed/racket/no-check
  (define-type ⊥ (∪))
  (define-type (¬ p) (→ p ⊥))
  (define-type (¬¬ p) (¬ (¬ p)))
  (: apply-cont (∀ (p) (→ (¬ p) p ⊥)))

  (define (apply-cont kv v) (kv v))
  (provide (all-defined-out))
)

(module triple-negation typed/racket/no-check
  (define-type ⊥ (∪))
  (define-type (¬ p) (→ p ⊥))
  (: apply-cont (∀ (p) (→ (¬ p) p ⊥)))
  (define (apply-cont kv v) (kv v))
  (define-type (¬¬  q) (¬ (¬  q)))
  (define-type (¬¬¬ q) (¬ (¬¬ q)))

  (: triple-negation (∀ (q) (→ (¬¬¬ q) (¬ q))))
  (define (triple-negation kkkq)
    (define (kq q)
      (define (kkq kq) (kq q))
      (kkkq kkq))
    kq)
  (define q 'hello)
  (provide (all-defined-out))
)

(module stage-18 typed/racket/no-check
  (define-type ⊥ (∪))
  (define-type (¬ p) (Pair (→ p ⊥) Natural))
  (define-type Label (¬ Label))

  (define n -1)
  (: label (→ Label))
  (define (label)
    (set! n (+ n 1))
    (let/cc kn
      (define ln (cons kn n))
      (apply-cont ln ln)))

  (: apply-cont (→ (¬ Label) Label ⊥))
  (define (apply-cont ln lm)
    (match-define (cons kn n) ln)
    (match-define (cons km m) lm)
    (display (format "  (k~a k~a)" n m))
    (kn lm))
  (provide (all-defined-out))
)

(module stage-20 racket

  (define (k0 kn)
    (displayln #\@)
    (define (kn+1 km)
      (display #\*)
      (kn km))
    (kn+1 kn+1))
  (provide (all-defined-out))
)

(module signature-1 typed/racket/no-check
  (define-type ⊥ (∪))
  (: cc      (∀ (p)   (→ (∪ p (→ p ⊥)))))
  (define (cc) (call/cc values))
)

(module signature-2 typed/racket/no-check
  (define-type ⊥ (∪))
  (: call/cc (∀ (p)   (→ (→ (→ p ⊥) p) p)))
  (define (cc) (call/cc values))
)

(module signature-3 typed/racket/no-check
  (define-type ⊥ (∪))
  (: call/cc (∀ (p q) (→ (→ (→ p q) p) p)))
  (define (cc) (call/cc values))
)

(module signature-4 typed/racket/no-check
  (define-type ⊥ (∪))
  (: call/cc (∀ (p)   (→ (→ (→ p ⊥) ⊥) p)))
  (define (cc) (call/cc values))
)

(module signature-5 typed/racket/no-check
  (define-type ⊥ (∪))
  (: absurd  (∀ (q)   (→ ⊥ q)))
  (define absurd (case-λ))
)

(module+ test
  (require (prefix-in primitive: (submod ".." stage-1))
           (prefix-in label: (submod ".." stage-3))
           (prefix-in elimination: (submod ".." stage-6))
           (prefix-in trace: (submod ".." stage-18))
           (prefix-in yin: (submod ".." stage-20))
           (prefix-in tn: (submod ".." triple-negation)))
  (check-equal? (label:mul) 1)
  (check-equal? (label:mul 2 3 4) 24)
  (check-equal? (label:mul 2 0 3) 0)
  (check-equal? (count-to-seven primitive:label primitive:goto) 7)
  (check-equal? (elimination:call/cc (λ (k) (+ 10 (k 4)))) 4)
  (check-true (output-starts-with?
               (λ () (let ([kn (trace:label)])
                       (displayln #\@)
                       (let ([kn+1 (trace:label)])
                         (display #\*)
                         (trace:apply-cont kn kn+1))))
               "  (k0 k0)@\n  (k1 k1)*  (k0 k1)@\n  (k2 k2)*  (k1 k2)*  (k0 k2)@\n"))
  (check-true (output-starts-with? (λ () (yin:k0 yin:k0)) "@\n*@\n**@\n***@"))
  ;; 三重否定律：把 DNI 升两层的延续降回来，行为和原来的一样，什么也不捕获
  (check-equal? (let/cc k (define (kkkq kkq) (kkq k)) (let ([kq (tn:triple-negation kkkq)]) (kq 'hello))) 'hello)
  (check-equal? ((tn:triple-negation (λ (kkq) (kkq (λ (q) (list 'got q))))) 7) '(got 7)))
