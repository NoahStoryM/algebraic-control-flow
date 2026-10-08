#lang racket
(provide cps)
(require (only-in racket/match [match-lambda match-λ]))

(require racket/control)

(define (cps exp)
  (define trivial* (mutable-seteq))
  (define (trivial? x) (set-member? trivial* x))
  (define (add-trivial! x) (set-add! trivial* x))
  (for-each add-trivial!
   '(identity values
     display displayln
     zero? add1 sub1
     + - * /
     = < <= > >=
     eq? eqv? equal?))

  (define (β? b v)
    (match b
      [`((λ (,u) ,u) ,e) (eq? e v)]
      [`((λ (,u) ,b) ,e)
       (and (eq? b v)
            (if (eq? u v)
                (eq? e v)
                (not (pair? e))))]
      [_ (eq? b v)]))
  (define (η? k v)
    (match k
      [`(λ (,u) ,b)
       (or (eq? u v)
           (not (if (pair? b)
                    (memq v (flatten b))
                    (eq? b v))))]
      [(? trivial?) (not (eq? k v))]
      [_ #f]))

  (define ((make-genvar name [n 0]))
    (define var (string->symbol (format "~a.~a" name n)))
    (when (eq? name 'k) (add-trivial! var))
    (set! n (add1 n))
    var)
  (define fv (make-genvar 'v))
  (define fk (make-genvar 'k))

  (define id (reset (shift k k)))
  (define (cps1 exp ctx) (reset (ctx (cps0 exp))))
  (define cps0
    (match-λ
      ['abort (cps0 '(λ (v) (shift _ v)))]
      [(? (not/c pair?) x) x]
      [`(λ ,x* ,body)
       (define kn (fk))
       (define ctx0 (reset `(,kn ,(shift k k))))
       `(λ ,x* (λ (,kn) ,(cps1 body ctx0)))]

      [`(reset ,body)
       (cps1 body id)]
      [`(shift _ ,body)
       (shift _ (cps1 body id))]
      [`(shift ,k ,body)
       (add-trivial! k)
       (define r
         (match `(λ (,k) ,(cps1 body id))
           [`(λ (,k) ,b)      #:when (β? b k) id]
           [`(λ (,k) (,r ,k)) #:when (η? r k) (λ (k) `(,r ,k))]
           [r                                 (λ (k) `(,r ,k))]))
       (shift ctx
         (define vn (fv))
         (match `(λ (,vn) ,(ctx vn))
           [`(λ (,vn) ,b)       #:when (β? b vn) (r 'values)]
           [`(λ (,vn) (,k ,vn)) #:when (η? k vn) (r k)]
           [k                                    (r k)]))]

      [`(let/lc ,k ,body)
       (cps0 `(shift ,k (,k ,body)))]
      [`(let/cc ,k ,body)
       (define vn (fv))
       (define kn (fk))
       (cps0 `(let/lc ,kn (let ([,k (λ (,vn) (abort (,kn ,vn)))]) ,body)))]

      [`(if ,test ,conseq ,alt)
       (shift ctx
         (define (r k)
           (define kn (fk))
           (cond
             [(eq? k 'values)  (cps-if id)]
             [(symbol? k)      (cps-if (reset `(,k  ,(shift k k))))]
             [else `((λ (,kn) ,(cps-if (reset `(,kn ,(shift k k))))) ,k)]))
         (define vn (fv))
         (define t (cps0 test))
         (define (cps-if ctx0)
           `(if ,t ,(cps1 conseq ctx0) ,(cps1 alt ctx0)))
         (match `(λ (,vn) ,(ctx vn))
           [`(λ (,vn) ,b)       #:when (β? b vn) (r 'values)]
           [`(λ (,vn) (,k ,vn)) #:when (η? k vn) (r k)]
           [k                                    (r k)]))]

      [`(let* () ,body)
       (cps0 `(let () ,body))]
      [`(let* ([,x ,exp] . ,bind*) ,body)
       (cps0 `(let ([,x ,exp]) (let* ,bind* ,body)))]
      [`(let ([,x* ,exp*] ...) ,body)
       (cps0 `((λ ,x* ,body) . ,exp*))]
      [`((λ () ,body))
       (cps0 body)]
      [`((λ (,x) ,body) ,rand)
       (shift ctx
         (define d (cps0 rand))
         (match `(λ (,x) ,(cps1 body ctx))
           [`(λ (,v) ,b)      #:when (β? b v) d]
           [`(λ (,v) (,k ,v)) #:when (η? k v) `(,k ,d)]
           [k                                 `(,k ,d)]))]
      [`((λ ,x* ,body) . ,rand*)
       (shift ctx
         (define k `(λ ,x* ,(cps1 body ctx)))
         (define d* (map cps0 rand*))
         `(,k . ,d*))]

      [`(abort . ,rand*) (cps0 `((λ (v) (shift _ v)) . ,rand*))]

      [`(,(? trivial? r) . ,rand*)
       (shift ctx
         (define vn (fv))
         (define d* (map cps0 rand*))
         (define r* `(,r . ,d*))
         (match `(λ (,vn) ,(ctx vn))
           [`(λ (,vn) ,b)       #:when (β? b vn) r*]
           [`(λ (,vn) (,k ,vn)) #:when (η? k vn) `(,k ,r*)]
           [k                                    `(,k ,r*)]))]

      [`(,rator . ,rand*)
       (shift ctx
         (define vn (fv))
         (define r  (cps0 rator))
         (define d* (map cps0 rand*))
         (define r* `(,r . ,d*))
         (match `(λ (,vn) ,(ctx vn))
           [`(λ (,vn) ,b)       #:when (β? b vn) `(,r* values)]
           [`(λ (,vn) (,k ,vn)) #:when (η? k vn) `(,r* ,k)]
           [k                                    `(,r* ,k)]))]))

  (cps1 exp id))

(module+ test
  (require rackunit "../../tools/check-output-prefix.rkt")
  (check-equal? (cps '(if a b c)) '(if a b c))
  (check-equal? (cps '(add1 (if a b c)))
                '(if a (add1 b) (add1 c)))
  (check-equal? (cps '(f (if a b c)))
                '((λ (k.0) (if a (k.0 b) (k.0 c)))
                  (λ (v.1) ((f v.1) values))))
  (check-equal?
   (cps '(reset (let ([f abort]) (+ 1 (f 5)))))
   '((λ (f) ((f 5) (λ (v.1) (+ 1 v.1))))
     (λ (v) (λ (k.0) v))))
  ;; 对具体程序同时核对编译输出的运行值与宿主定界计算的结果。
  (define (run compiled)
    (parameterize ([current-namespace (make-base-namespace)])
      (eval compiled)))
  (for ([source '((reset (+ 10 (shift k (k 3))))
                  (reset (+ 10 (shift k 3)))
                  (let ([x (reset (shift k (k 3)))]) (+ x 100)))])
    (check-equal? (run (cps source))
                  (parameterize ([current-namespace (make-base-namespace)])
                    (eval '(require racket/control))
                    (eval `(reset ,source)))))
  ;; 「再看阴阳谜题」：平凡集合里的名字不是一等值，延续与内建函数都如此；包进 lambda 才是。
  (check-exn #rx"not a procedure.*given: 3"
             (λ () (run (cps '(let ([id (reset (shift k k))]) (id (id 3)))))))
  (check-equal? (run (cps '(let ([id (reset (shift k (λ (v) (k v))))]) (id (id 3))))) 3)
  (check-equal? (cps '(let ([f add1]) (f 41)))
                '((λ (f) ((f 41) values)) add1))
  (check-exn #rx"not a procedure.*given: 42"
             (λ () (run (cps '(let ([f add1]) (f 41))))))
  (check-equal? (cps '(let ([f (λ (x) (add1 x))]) (f 41)))
                '((λ (f) ((f 41) values)) (λ (x) (λ (k.0) (k.0 (add1 x))))))
  (check-equal? (run (cps '(let ([f (λ (x) (add1 x))]) (f 41)))) 42)
  (check-true
   (output-starts-with?
    (λ ()
      (run (cps '(reset
                  (let* ([label (λ () (let/lc k k))]
                         [yin   (label)]
                         [_     (display #\@)]
                         [yang  (label)]
                         [_     (display #\*)])
                    (yin yang))))))
    "@*@**@***@")))


;; 正文推导中的独立版本，同名定义各有自己的作用域。

(module stage-1 racket

  (provide (all-defined-out))
  (define (fib n)
    (if (< n 2)
        n
        (+ (fib (- n 1))
           (fib (- n 2)))))
)

(module stage-2 racket

  (provide (all-defined-out))
  (define (fib n) (fib/k n '()))

  (define (fib/k n k)
    (if (< n 2)
        (apply-cont k n)
        (fib/k (- n 1) (cons `(fib ,(- n 2)) k))))

  (define (apply-cont k v)
    (match k
      ['() v]
      [`((fib ,n-2) . ,k) (fib/k n-2 (cons `(add ,v) k))]
      [`((add ,w) . ,k)   (apply-cont k (+ w v))]))
)

(module stage-3 racket

  (provide (all-defined-out))
  (define (fib/k n k)
    (if (< n 2)
        (k n)
        (fib/k (- n 1)
               (λ (v)
                 (fib/k (- n 2)
                        (λ (w)
                          (k (+ v w))))))))
)

(module stage-4 racket
  (provide make-genvar)
  (provide (all-defined-out))
  (define ((make-genvar name [n 0]))
    (define var (string->symbol (format "~a.~a" name n)))
    (set! n (add1 n))
    var)
)

(module stage-5 racket
  (require (submod ".." stage-4))
  (provide (all-defined-out))
  (define (anf exp)
    (define fv (make-genvar 'v))
    (define (id v) v)
    (define (anf1 exp ctx)
      (match exp
        [(? (not/c pair?) x) (ctx x)]
        [`(λ ,x* ,body)
         (ctx `(λ ,x* ,(anf1 body id)))]
        [`(if ,test ,conseq ,alt)
         (anf1 test
               (λ (t) (anf1 conseq
                            (λ (c) (anf1 alt
                                   (λ (a) (ctx `(if ,t ,c ,a))))))))]
        [`(let ([,x ,e]) ,body)
         (anf1 `((λ (,x) ,body) ,e) ctx)]
        [`((λ (,x) ,body) ,rand)
         (anf1 rand (λ (d) (anf1 body (λ (b) (ctx `(let ([,x ,d]) ,b))))))]
        [`(,rator ,rand)
         (anf1 rator (λ (r) (anf1 rand (λ (d) (ctx `(,r ,d))))))]))
    (anf1 exp id))
)

(module stage-7 racket

  (provide (all-defined-out))
  (define (anf0 exp)
    (match exp
      [(? (not/c pair?) x) x]
      [`(λ ,x* ,body)
       `(λ ,x* ,(anf0 body))]
      [`(if ,test ,conseq ,alt)
       `(if ,(anf0 test) ,(anf0 conseq) ,(anf0 alt))]
      [`(let ([,x ,e]) ,body)
       (anf0 `((λ (,x) ,body) ,e))]
      [`((λ (,x) ,body) ,rand)
       `(let ([,x ,(anf0 rand)]) ,(anf0 body))]
      [`(,rator ,rand)
       `(,(anf0 rator) ,(anf0 rand))]))
)

(module stage-9 racket
  (require (submod ".." stage-4))
  (provide (all-defined-out))
  (define (anf exp)
    (define fv (make-genvar 'v))
    (define (id v) v)
    (define (anf1 exp ctx)
      (match exp
        [(? (not/c pair?) x) (ctx x)]
        [`(λ ,x* ,body)
         (ctx `(λ ,x* ,(anf1 body id)))]
        [`(if ,test ,conseq ,alt)
         (anf1 test
               (λ (t) `(if ,t ,(anf1 conseq ctx) ,(anf1 alt ctx))))]
        [`(let ([,x ,e]) ,body)
         (anf1 `((λ (,x) ,body) ,e) ctx)]
        [`((λ (,x) ,body) ,rand)
         (anf1 rand (λ (d) `(let ([,x ,d]) ,(anf1 body ctx))))]
        [`(,rator ,rand)
         (define vn (fv))
         (anf1 rator
               (λ (r)
                 (anf1 rand
                       (λ (d)
                         `(let ([,vn (,r ,d)])
                            ,(ctx vn))))))]))
    (anf1 exp id))
)

(module stage-12 racket
  (require racket/control)
(provide anf0)
(define (anf1 exp ctx) (ctx exp))
  (provide (all-defined-out))
  (define (anf0 exp) (shift ctx (anf1 exp ctx)))
)

(module stage-14 racket
  (require racket/control (submod ".." stage-4))
  (provide (all-defined-out))
  (define (anf exp)
    (define fv (make-genvar 'v))
    (define (anf0 exp) (shift ctx (anf1 exp ctx)))
    (define (anf1 exp ctx)
      (match exp
        [(? (not/c pair?) x) (ctx x)]
        [`(λ ,x* ,body)
         (ctx `(λ ,x* ,(reset (anf0 body))))]
        [`(if ,test ,conseq ,alt)
         (reset
          (let ([t (anf0 test)])
            `(if ,t ,(reset (ctx (anf0 conseq))) ,(reset (ctx (anf0 alt))))))]
        [`(let ([,x ,e]) ,body)
         (reset (ctx (anf0 `((λ (,x) ,body) ,e))))]
        [`((λ (,x) ,body) ,rand)
         (reset
          (let ([d (anf0 rand)])
            `(let ([,x ,d]) ,(reset (ctx (anf0 body))))))]
        [`(,rator ,rand)
         (define vn (fv))
         (reset
          (let ([r (anf0 rator)])
            (reset
             (let ([d (anf0 rand)])
               `(let ([,vn (,r ,d)])
                  ,(ctx vn))))))]))
    (reset (anf0 exp)))
)

(module stage-15 racket
  (require racket/control (only-in (submod ".." stage-12) anf0))
  (provide (all-defined-out))
  (define (anf1 exp ctx) (reset (ctx (anf0 exp))))
)

(module stage-20 racket
  (require racket/control (submod ".." stage-4))
(require (only-in racket/match [match-lambda match-λ]))
  (provide (all-defined-out))
  (define (anf exp)
    (define fv (make-genvar 'v))
    (define id (reset (shift k k)))
    (define (anf1 exp ctx) (reset (ctx (anf0 exp))))
    (define anf0
      (match-λ
        [(? (not/c pair?) x) x]
        [`(λ ,x* ,body)
         `(λ ,x* ,(anf1 body id))]
        [`(if ,test ,conseq ,alt)
         (shift ctx
           (define t (anf0 test))
           `(if ,t ,(anf1 conseq ctx) ,(anf1 alt ctx)))]
        [`(let ([,x ,e]) ,body)
         (anf0 `((λ (,x) ,body) ,e))]
        [`((λ (,x) ,body) ,rand)
         (shift ctx
           (define d (anf0 rand))
           `(let ([,x ,d]) ,(anf1 body ctx)))]
        [`(,rator . ,rand*)
         (shift ctx
           (define vn (fv))
           (define r (anf0 rator))
           (define d* (map anf0 rand*))
           `(let ([,vn (,r . ,d*)]) ,(ctx vn)))]))
    (anf1 exp id))
)

(module stage-34 racket

  (provide (all-defined-out))
  (define (k0 kn)
    (display #\@)
    (define (kn+1 k)
      (display #\*)
      (kn k))
    (kn+1 kn+1))
)

(module stage-67 racket

  (provide (all-defined-out))
  (define (k0 kn)
    (display #\@)
    (define (kn+1 k)
      (display #\*)
      ((kn k) values))
    (kn+1 (λ (v) (λ (k.1) (k.1 (kn+1 v))))))
)

(module+ test
  (require "../../tools/check-output-prefix.rkt"
           (prefix-in direct: (submod ".." stage-1))
           (prefix-in data: (submod ".." stage-2))
           (prefix-in closure: (submod ".." stage-3))
           (prefix-in gensym: (submod ".." stage-4))
           (prefix-in eager: (submod ".." stage-5))
           (prefix-in naive: (submod ".." stage-7))
           (prefix-in branch: (submod ".." stage-9))
           (prefix-in shift: (submod ".." stage-14))
           (prefix-in final: (submod ".." stage-20))
           (prefix-in yin: (submod ".." stage-34))
           (prefix-in cps-yin: (submod ".." stage-67)))
  (for ([fib (list direct:fib data:fib)])
    (check-equal? (fib 10) 55))
  (check-equal? (closure:fib/k 10 values) 55)
  (define fresh (gensym:make-genvar 'v))
  (check-equal? (list (fresh) (fresh)) '(v.0 v.1))
  (for ([anf (list eager:anf branch:anf shift:anf final:anf)])
    (check-equal? (anf 'x) 'x))
  (check-equal? (naive:anf0 '(if t a b)) '(if t a b))
  (check-equal? (final:anf '(f x)) '(let ([v.0 (f x)]) v.0))
  (check-true (output-starts-with? (λ () (yin:k0 yin:k0)) "@*@**@***@"))
  (check-true (output-starts-with?
               (λ () (cps-yin:k0 (λ (v) (λ (k.0) (k.0 (cps-yin:k0 v))))))
               "@*@**@***@")))
