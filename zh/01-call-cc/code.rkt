#lang racket
;; 每次推导保留正文里的名字；循环定义放进不同子模块，各自选择底层原语。

(module label-to-cc racket
  (require (only-in racket/base [call/cc primitive-call/cc]))
  (provide label goto cc call/cc mul)
  (define (goto l) (l l))
  (define (label) (primitive-call/cc goto))

  (define (cc)
    (define v* #f)
    (define l (label))
    (if v*
        (apply values v*)
        (λ vs (set! v* vs) (goto l))))

  (define (call/cc proc)
    (define v* (cc))
    (if (list? v*)
        (apply values v*)
        (proc (λ vs (v* vs)))))

  (define (mul . r*)
    (define result (cc))
    (if (real? result)
        result
        (for/fold ([res (*)] #:result (result res))
                  ([r (in-list r*)])
          (if (zero? r)
              (result r)
              (* res r))))))

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
    (define v* #f)
    (define l (label))
    (if v*
        (apply values v*)
        (proc (λ vs (set! v* vs) (goto l)))))
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
           (prefix-in d: (submod ".." cc-to-label)))

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
  (check-equal? (a:call/cc (λ (k) (+ 100 (k 9)))) 9)
  (check-equal? (c:call/cc (λ (k) (+ 100 (k 9)))) 9)
  (check-equal? (let ([v (a:cc)]) (if (procedure? v) (v 42) v)) 42)
  (check-equal? (let ([v (c:cc)]) (if (procedure? v) (v 42) v)) 42)
  (check-true
   (output-starts-with?
    (λ ()
      (let ([yin (a:label)])
        (display #\@)
        (let ([yang (a:label)])
          (display #\*)
          (yin yang))))
    "@*@**@***@")))


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
  (require (rename-in racket/base [case-lambda case-λ]))
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

  (define (apply-cont k . v*) (apply k v*))
  (provide (all-defined-out))
)

(module stage-18 racket

  (define n -1)

  (define (cc)
    (set! n (+ n 1))
    (let/cc k
      (define l (cons k (string->symbol (string-append "k" (number->string n)))))
      (apply-cont l l)))

  (define (apply-cont kl l)
    (display (list (cdr kl) (cdr l)))
    (display #\tab)
    ((car kl) l))
  (provide (all-defined-out))
)

(module stage-20 racket

  (define (k0 kn)
    (display #\@)
    (define (kn+1 k)
      (display #\*)
      (kn k))
    (kn+1 kn+1))
  (provide (all-defined-out))
)

(module stage-22 typed/racket/no-check

  (define b 111)

  (: f (→ Real))

  (define (f) (* 1 b))
  (define (set-b! v) (set! b v))
  (provide (all-defined-out))
)

(module stage-23 typed/racket/no-check

  (define a (make-parameter 1))

  (define b 111)

  (: f (→ Real))

  (define (f) (* (a) b))
  (provide (all-defined-out))
)

(module stage-24 typed/racket/no-check
  (define-type ⊥ (∪))
  (define-type (¬ p) (→ p ⊥))
  (define (cc) (call/cc values))
  (define-type (¬¬ q) (¬ (¬ q)))

  (: wait/fc (∀ (q) (→ (¬¬ q) (¬¬ q))))

  (define (wait/fc kk)
    (define first? #t)
    (: k (∪ (¬ q) (¬¬ q)))
    ;; 首次：(cc) 返回这个位置作为延续；k : ¬¬q
    ;; 重入：(cc) 返回刚刚传递到这里的值；k : ¬q
    (define k (cc))
    (unless first? (kk k))
    (set! first? #f)
    k)
  (provide (all-defined-out))
)

(module stage-25 typed/racket/no-check
  (define-type ⊥ (∪))
  (define-type (¬ p) (→ p ⊥))
  (define-type (¬¬ p) (¬ (¬ p)))
  (define (cc) (call/cc values))
  (: wait/fc (∀ (q) (→ (→ (¬ q) q) (¬¬ q))))

  (define (wait/fc proc)
    (define first? #t)
    (define k (cc))
    (unless first? (call-with-values (λ () (proc k)) k))
    (set! first? #f)
    k)
  (provide (all-defined-out))
)

(module stage-26 typed/racket/no-check
  (require (submod ".." stage-25))
  (define (run-stage-26)
    (define a (make-parameter 1))

    (define b 111)

    (: f (¬ (¬ Real)))

    (define f (wait/fc (λ (_) (* (a) b))))
    (list (call/cc f) (begin (set! b 222) (call/cc f)) (parameterize ([a 2]) (call/cc f))))

  (provide (all-defined-out))
)

(module stage-27 racket
  (require (submod ".." stage-25))
  (define (run-stage-27)
    (define W1
      (dynamic-wind
        (λ () (displayln "C1: enter"))
        (λ () (wait/fc
               (λ (fc)
                 (displayln "reached the frozen context C1")
                 (fc 'hello))))
        (λ () (displayln "C1: exit"))))

    (define W2
      (dynamic-wind
        (λ () (displayln "C2: enter"))
        (λ () (wait/fc W1))
        (λ () (displayln "C2: exit"))))
    (displayln (call/cc W2)))

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
  (require (rename-in racket/base [case-lambda case-λ]))
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
           (prefix-in thunk: (submod ".." stage-22))
           (prefix-in param: (submod ".." stage-23))
           (prefix-in frozen0: (submod ".." stage-24))
           (prefix-in frozen: (submod ".." stage-25))
           (prefix-in context: (submod ".." stage-26))
           (prefix-in wind: (submod ".." stage-27)))
  (check-equal? (label:mul) 1)
  (check-equal? (label:mul 2 3 4) 24)
  (check-equal? (label:mul 2 0 3) 0)
  (check-equal? (count-to-seven primitive:label primitive:goto) 7)
  (check-equal? (elimination:call/cc (λ (k) (+ 10 (k 4)))) 4)
  (check-true (output-starts-with?
               (λ () (let ([kn (trace:cc)])
                       (displayln #\@)
                       (let ([kn+1 (trace:cc)])
                         (displayln #\*)
                         (trace:apply-cont kn kn+1))))
               "(k0 k0)\t@\n(k1 k1)\t*\n(k0 k1)\t@\n"))
  (check-true (output-starts-with? (λ () (yin:k0 yin:k0)) "@*@**@***@"))
  (check-equal? (let () (thunk:set-b! 111) (define a (thunk:f))
                 (thunk:set-b! 222) (list a (thunk:f))) '(111 222))
  (check-equal? (parameterize ([param:a 2]) (param:f)) 222)
  (check-equal? (call/cc (frozen0:wait/fc (λ (k) (k 42)))) 42)
  (check-equal? (call/cc (frozen:wait/fc (λ (_) 43))) 43)
  (check-equal? (context:run-stage-26) '(111 222 222))
  (check-equal?
   (with-output-to-string wind:run-stage-27)
   (string-append "C1: enter\nC1: exit\nC2: enter\nC2: exit\n"
                  "C2: enter\nC2: exit\nC1: enter\n"
                  "reached the frozen context C1\nC1: exit\nhello\n")))
