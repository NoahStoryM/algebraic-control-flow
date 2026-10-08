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
       (shift ctx
         (define vn (fv))
         (define r* (cps1 body id))
         (match `(λ (,vn) ,(ctx vn))
           [`(λ (,vn) ,b)       #:when (β? b vn) r*]
           [`(λ (,vn) (,k ,vn)) #:when (η? k vn) `(,k ,r*)]
           [k                                    `(,k ,r*)]))]
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
   '((λ (f) ((f 5) (λ (v.2) (+ 1 v.2))))
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

;; 「镜子破裂」：含命名 if，函数主体仍从 id 开始。
(module stage-delimited racket
  (require racket/control (submod ".." stage-4))
  (require (only-in racket/match [match-lambda match-λ]))
  (provide (all-defined-out))
  (define (anf exp)
    (define fv (make-genvar 'v))
    (define fk (make-genvar 'k))
    (define id (reset (shift k k)))
    (define (anf1 exp ctx) (reset (ctx (anf0 exp))))
    (define anf0
      (match-λ
        [(? (not/c pair?) x) x]
        [`(λ ,x* ,body)
         `(λ ,x* ,(anf1 body id))]
        [`(reset ,body)
         (shift ctx
           (define vn (fv))
           `(let ([,vn ,(anf1 body id)])
              ,(ctx vn)))]
        [`(shift ,k ,body)
         (shift ctx
           (define vn (fv))
           `(let ([,k (λ (,vn) ,(ctx vn))])
              ,(anf1 body id)))]
        [`(let/lc ,k ,body)
         (anf0 `(shift ,k (,k ,body)))]
        [`(let* () ,body)
         (anf0 body)]
        [`(let* ([,x ,e] . ,bind*) ,body)
         (anf0 `(let ([,x ,e]) (let* ,bind* ,body)))]
        [`(if ,test ,conseq ,alt)
         (shift ctx
           (define vn (fv))
           (define kn (fk))
           (define t (anf0 test))
           (define ctx0 (reset `(,kn ,(shift k k))))
           `(let ([,kn (λ (,vn) ,(ctx vn))])
              (if ,t ,(anf1 conseq ctx0) ,(anf1 alt ctx0))))]
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

;; 「调用者的延续」：含命名 if，用户函数显式接受调用者的延续。
(module stage-caller racket
  (require racket/control)
  (require (only-in racket/match [match-lambda match-λ]))
  (provide (all-defined-out))
  (define (anf exp)
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
    (define ((make-genvar name [n 0]))
      (define var (string->symbol (format "~a.~a" name n)))
      (when (eq? name 'k) (add-trivial! var))
      (set! n (add1 n))
      var)
    (define fv (make-genvar 'v))
    (define fk (make-genvar 'k))
    (define id (reset (shift k k)))
    (define (anf1 exp ctx) (reset (ctx (anf0 exp))))
    (define anf0
      (match-λ
        [(? (not/c pair?) x) x]
        [`(λ ,x* ,body)
         (define kn (fk))
         (define ctx0 (reset `(,kn ,(shift k k))))
         `(λ ,x* (λ (,kn) ,(anf1 body ctx0)))]
        [`(reset ,body)
         (shift ctx
           (define vn (fv))
           `(let ([,vn ,(anf1 body id)])
              ,(ctx vn)))]
        [`(shift ,k ,body)
         (add-trivial! k)
         (shift ctx
           (define vn (fv))
           `(let ([,k (λ (,vn) ,(ctx vn))])
              ,(anf1 body id)))]
        [`(let/lc ,k ,body)
         (anf0 `(shift ,k (,k ,body)))]
        [`(let* () ,body)
         (anf0 body)]
        [`(let* ([,x ,e] . ,bind*) ,body)
         (anf0 `(let ([,x ,e]) (let* ,bind* ,body)))]
        [`(if ,test ,conseq ,alt)
         (shift ctx
           (define vn (fv))
           (define kn (fk))
           (define t (anf0 test))
           (define ctx0 (reset `(,kn ,(shift k k))))
           `(let ([,kn (λ (,vn) ,(ctx vn))])
              (if ,t ,(anf1 conseq ctx0) ,(anf1 alt ctx0))))]
        [`(let ([,x ,e]) ,body)
         (anf0 `((λ (,x) ,body) ,e))]
        [`((λ (,x) ,body) ,rand)
         (shift ctx
           (define d (anf0 rand))
           `(let ([,x ,d]) ,(anf1 body ctx)))]
        [`(,(? trivial? r) . ,rand*)
         (shift ctx
           (define vn (fv))
           (define d* (map anf0 rand*))
           `(let ([,vn (,r . ,d*)]) ,(ctx vn)))]
        [`(,rator . ,rand*)
         (shift ctx
           (define vn (fv))
           (define r (anf0 rator))
           (define d* (map anf0 rand*))
           `((,r . ,d*) (λ (,vn) ,(ctx vn))))]))
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

(module+ test
  (require (prefix-in delimited: (submod ".." stage-delimited))
           (prefix-in caller: (submod ".." stage-caller)))
  ;; 每个展示的编译输出分别对其所属阶段断言，不能以最终版代替中间版。
  (check-equal?
   (delimited:anf '(reset (+ 1 (shift k (k 42)))))
   '(let ([v.0 (let ([k (λ (v.2) (let ([v.1 (+ 1 v.2)]) v.1))]) (let ([v.3 (k 42)]) v.3))])
      v.0))
  (check-equal?
   (delimited:anf '(+ 10 (reset (+ 1 (shift k 42)))))
   '(let ([v.1 (let ([k (λ (v.3) (let ([v.2 (+ 1 v.3)]) v.2))]) 42)])
      (let ([v.0 (+ 10 v.1)]) v.0)))
  (check-equal?
   (delimited:anf '(reset (let* ((kn (let/lc k0 k0)) (k (let/lc kn+1 kn+1))) (kn k))))
   '(let ([v.0
           (let ([k0
                  (λ (v.1)
                    (let ([kn v.1])
                      (let ([kn+1 (λ (v.2) (let ([k v.2]) (let ([v.3 (kn k)]) v.3)))])
                        (let ([v.4 (kn+1 kn+1)]) v.4))))])
             (let ([v.5 (k0 k0)]) v.5))])
      v.0))
  (check-equal?
   (delimited:anf '(reset (let ([f (λ (x) (shift k 999))]) (add1 (f 42)))))
   '(let ([v.0
           (let ([f (λ (x) (let ([k (λ (v.1) v.1)]) 999))])
             (let ([v.3 (f 42)]) (let ([v.2 (add1 v.3)]) v.2)))])
      v.0))
  (check-equal?
   (caller:anf '(reset (let ([f (λ (x) (shift k 999))]) (add1 (f 42)))))
   '(let ([v.0
           (let ([f (λ (x) (λ (k.0) (let ([k (λ (v.1) (k.0 v.1))]) 999)))])
             ((f 42) (λ (v.3) (let ([v.2 (add1 v.3)]) v.2))))])
      v.0))
  (check-equal?
   (caller:anf '(λ (n) (f (g n))))
   '(λ (n) (λ (k.0) ((g n) (λ (v.1) ((f v.1) (λ (v.0) (k.0 v.0))))))))
  (check-equal? (cps '(if a b c)) '(if a b c))
  (check-equal? (cps '(add1 (if a b c))) '(if a (add1 b) (add1 c)))
  (check-equal?
   (cps '(f (if a b c)))
   '((λ (k.0) (if a (k.0 b) (k.0 c))) (λ (v.1) ((f v.1) values))))
  (check-equal? (cps '(λ (n) (f (g n)))) '(λ (n) (λ (k.0) ((g n) (λ (v.1) ((f v.1) k.0))))))
  (check-equal?
   (cps '(reset (let ([f (λ (x) (shift k 999))]) (add1 (f 42)))))
   '((λ (f) ((f 42) add1)) (λ (x) (λ (k.0) ((λ (k) 999) k.0)))))
  (check-equal?
   (cps '(reset (let ([f abort]) (+ 1 (f 5)))))
   '((λ (f) ((f 5) (λ (v.2) (+ 1 v.2)))) (λ (v) (λ (k.0) v))))
  (check-equal?
   (cps '(let ([k (reset (let ([x (let/cc k (abort k))]) (+ x 2)))]) (+ (reset (k 3)) 100)))
   '((λ (k) ((λ (v.7) (+ v.7 100)) ((k 3) values)))
     ((λ (k.0) (λ (v.1) (λ (k.1) (k.0 v.1)))) (λ (x) (+ x 2)))))
  (check-equal?
   (cps '(let ([v (reset (let* ((x 3) (y (+ 2 x))) (abort y)))]) (+ 10 v)))
   '((λ (v) (+ 10 v)) ((λ (x) (+ 2 x)) 3)))
  (check-equal?
   (cps '(let ([v (reset (let* ((x (shift k 3)) (y (+ 2 x))) (abort y)))]) (+ 10 v)))
   '((λ (v) (+ 10 v)) ((λ (k) 3) (λ (x) (+ 2 x)))))
  (check-equal?
   (cps '(let ([v (reset (let* ((x (shift k (k 3))) (y (+ 2 x))) (abort y)))]) (+ 10 v)))
   '((λ (v) (+ 10 v)) ((λ (k) (k 3)) (λ (x) (+ 2 x)))))
  (check-equal?
   (cps
    '(let ([v (reset (let* ((x (shift k (let ([r (k 3)]) (k r)))) (y (+ 2 x))) (abort y)))])
       (+ 10 v)))
   '((λ (v) (+ 10 v)) ((λ (k) (k (k 3))) (λ (x) (+ 2 x)))))
  (check-equal?
   (cps
    '(reset
      (let* ((label (λ () (let/lc k k)))
             (yin (label))
             (_ (display #\@))
             (yang (label))
             (_ (display #\*)))
        (yin yang))))
   '((λ (label)
       ((label)
        (λ (yin)
          ((λ (_) ((label) (λ (yang) ((λ (_) ((yin yang) values)) (display #\*)))))
           (display #\@)))))
     (λ () (λ (k.0) ((λ (k) (k k)) k.0)))))
  (check-equal?
   (cps '(let ([id (reset (shift k k))]) (id (id 3))))
   '((λ (id) ((id 3) (λ (v.3) ((id v.3) values)))) values))
  (check-equal?
   (cps '(let ([id (reset (shift k (λ (v) (k v))))]) (id (id 3))))
   '((λ (id) ((id 3) (λ (v.4) ((id v.4) values))))
     ((λ (k) (λ (v) (λ (k.0) (k.0 (k v))))) values)))
  (check-equal? (cps '(let ([f add1]) (f 41))) '((λ (f) ((f 41) values)) add1))
  (check-equal?
   (cps '(let ([f (λ (x) (add1 x))]) (f 41)))
   '((λ (f) ((f 41) values)) (λ (x) (λ (k.0) (k.0 (add1 x))))))
  (check-equal?
   (cps
    '(reset
      (let* ((kn (let/lc k0 (λ (v) (k0 v))))
             (_ (display #\@))
             (k (let/lc kn+1 (λ (v) (kn+1 v))))
             (_ (display #\*)))
        (kn k))))
   '((λ (k0) (k0 (λ (v) (λ (k.0) (k.0 (k0 v))))))
     (λ (kn)
       ((λ (_)
          ((λ (kn+1) (kn+1 (λ (v) (λ (k.1) (k.1 (kn+1 v))))))
           (λ (k) ((λ (_) ((kn k) values)) (display #\*)))))
        (display #\@)))))
  ;; 命名 if 的实现沿用正文；调用者版中生成的 k.n 也必须是平凡名字。
  (check-equal? (delimited:anf '(f (if a b c)))
                '(let ([k.0 (λ (v.1) (let ([v.0 (f v.1)]) v.0))])
                   (if a (k.0 b) (k.0 c))))
  (check-equal? (caller:anf '(f (if a b c)))
                '(let ([k.0 (λ (v.1) ((f v.1) (λ (v.0) v.0)))])
                   (if a (k.0 b) (k.0 c))))
  (define example-999 '(reset (let ([f (λ (x) (shift k 999))]) (add1 (f 42)))))
  (check-equal? (run (delimited:anf example-999)) 1000)
  (check-equal? (run (caller:anf example-999)) 999)
  (check-equal? (run (cps example-999)) 999)
  (check-equal? (run (delimited:anf '(reset (+ 1 (shift k (k 42)))))) 43)
  (check-equal? (run (delimited:anf '(+ 10 (reset (+ 1 (shift k 42)))))) 52)
  (define label-puzzle
    '(reset (let* ([label (λ () (let/lc k k))]
                   [yin (label)] [_ (display #\@)]
                   [yang (label)] [_ (display #\*)])
              (yin yang))))
  (define label-result (delimited:anf label-puzzle))
  (check-equal?
   label-result
   '(let ([v.0
           (let ([label (λ () (let ([k (λ (v.1) v.1)]) (let ([v.2 (k k)]) v.2)))])
             (let ([v.3 (label)])
               (let ([yin v.3])
                 (let ([v.4 (display #\@)])
                   (let ([_ v.4])
                     (let ([v.5 (label)])
                       (let ([yang v.5])
                         (let ([v.6 (display #\*)])
                           (let ([_ v.6]) (let ([v.7 (yin yang)]) v.7))))))))))])
      v.0))
  ;; 「诊断」展示的 label 子式，使用完整编译过程中分配的编号。
  (check-equal? (match label-result
                  [`(let ([v.0 (let ([label ,compiled]) ,_)]) v.0) compiled])
                '(λ () (let ([k (λ (v.1) v.1)]) (let ([v.2 (k k)]) v.2))))
  (check-equal? (with-output-to-string (λ () (run label-result))) "@*")
  (check-true (output-starts-with? (λ () (run (caller:anf label-puzzle))) "@*@**@***@"))
  (define (desugar exp)
    (match exp
      [`(let ([,x ,e]) ,body) `((λ (,x) ,(desugar body)) ,(desugar e))]
      [(? pair?) (map desugar exp)]
      [_ exp]))
  (define before-999
    '((λ (v.0) v.0)
      ((λ (f) ((f 42) (λ (v.3) ((λ (v.2) v.2) (add1 v.3)))))
       (λ (x) (λ (k.0) ((λ (k) 999) (λ (v.1) (k.0 v.1))))))))
  (define after-999
    '((λ (f) ((f 42) add1)) (λ (x) (λ (k.0) ((λ (k) 999) k.0)))))
  (check-equal? (desugar (caller:anf example-999)) before-999)
  (check-equal? (cps example-999) after-999)
  (define (lambda-count exp)
    (if (pair? exp)
        (+ (if (eq? (car exp) 'λ) 1 0) (apply + (map lambda-count exp)))
        0))
  (check-equal? (lambda-count before-999) 8)
  (check-equal? (lambda-count after-999) 4)
  (check-equal? (run before-999) 999)
  ;; 「混合体」的手工 β/η 归约，按新版编号核对结果。
  (for ([exp '((λ (v.3) (let ([v.2 (add1 v.3)]) v.2))
                (λ (v.3) ((λ (v.2) v.2) (add1 v.3)))
                (λ (v.3) (add1 v.3)) add1)])
    (check-equal? ((run exp) 999) 1000))
  (check-equal? (run '((λ (v.2) v.2) (add1 999))) (run '(add1 999)))
  ;; 最终版文中提供了运行结果的有限例子。
  (for ([source '((reset (let ([f abort]) (+ 1 (f 5))))
                  (let ([k (reset (let ([x (let/cc k (abort k))]) (+ x 2)))])
                    (+ (reset (k 3)) 100))
                  (let ([v (reset (let* ([x 3] [y (+ 2 x)]) (abort y)))]) (+ 10 v))
                  (let ([v (reset (let* ([x (shift k 3)] [y (+ 2 x)]) (abort y)))]) (+ 10 v))
                  (let ([v (reset (let* ([x (shift k (k 3))] [y (+ 2 x)]) (abort y)))]) (+ 10 v))
                  (let ([v (reset (let* ([x (shift k (let ([r (k 3)]) (k r)))]
                                        [y (+ 2 x)]) (abort y)))]) (+ 10 v)))]
        [expected '(5 105 15 13 15 17)])
    (check-equal? (run (cps source)) expected))
  (check-true
   (output-starts-with?
    (λ () (run (cps '(reset
                      (let* ([kn (let/lc k0 (λ (v) (k0 v)))]
                             [_ (display #\@)]
                             [k (let/lc kn+1 (λ (v) (kn+1 v)))]
                             [_ (display #\*)])
                        (kn k))))))
    "@*@**@***@"))
  ;; compiler-claims.md c 节的六例：先独立运行源程序，再比对各阶段的打印。
  (define order-cases
    '((eq? (reset (display 1)) (display 2))
      (eq? (display 1) (reset (display 2)))
      (let ([f (λ (a b) a)]) (f (reset (display 1)) (display 2)))
      (+ (reset (let ([a (display 1)]) 1)) (let ([b (display 2)]) 2))
      ((reset (let ([a (display 1)]) add1)) (let ([b (display 2)]) 2))
      (+ (reset (+ 10 (shift k (let ([a (display 1)]) (k 1)))))
         (let ([b (display 2)]) 2))))
  (define (direct source)
    (parameterize ([current-namespace (make-base-namespace)])
      (eval '(require racket/control))
      (eval `(reset ,source))))
  (define (observe thunk)
    (define out (open-output-string))
    (define result
      (parameterize ([current-output-port out])
        (with-handlers ([exn:fail? values]) (thunk))))
    (values (get-output-string out) result))
  (for ([source order-cases] [n (in-naturals)])
    (define-values (printed expected) (observe (λ () (direct source))))
    (check-equal? printed "12")
    (for ([compiler (list delimited:anf caller:anf cps)] [stage (in-naturals)])
      (define-values (actual result) (observe (λ () (run (compiler source)))))
      (check-equal? actual printed (format "c~a 阶段 ~a" (add1 n) stage))
      (if (and (= n 4) (> stage 0))
          ;; #49 已定：内建函数名不是一等值。顺序修复仍须先打印 12 再报错。
          (check-true (and (exn:fail? result)
                           (regexp-match? #rx"not a procedure.*given: 3" (exn-message result))))
          (check-equal? result expected))))
  ;; 支持的用户函数作 rator 值，顺序与最终返回值都一致。
  (define wrapped-rator
    '((reset (let ([a (display 1)]) (λ (x) (add1 x))))
      (let ([b (display 2)]) 2)))
  (for ([compiler (list delimited:anf caller:anf cps)])
    (define-values (printed result) (observe (λ () (run (compiler wrapped-rator)))))
    (check-equal? printed "12")
    (check-equal? result 3)))
