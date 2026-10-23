#lang racket
(provide cps counts reset-counts!)
;; 计数版：统计编译器每次用 shift 取得的 ctx 被调用了几次（不改变编译逻辑）
(require (for-syntax racket/base))
(define counts (make-hash))
(define (reset-counts!) (hash-clear! counts))
(define-syntax (shift-counted stx)
  (syntax-case stx ()
    [(_ name label body ...)
     #'(shift raw
         (define tag (list label (gensym)))
         (hash-set! counts tag 0)
         (define (name v) (hash-update! counts tag add1) (raw v))
         (let () body ...))]))
;; 本机 Racket 版本的 racket/match 没有 match-λ，用 match-lambda 别名代替（不影响语义）
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
       (shift-counted _ "ctx@(shift _" (cps1 body id))]
      [`(shift ,k ,body)
       (add-trivial! k)
       (define r
         (match `(λ (,k) ,(cps1 body id))
           [`(λ (,k) ,b)      #:when (β? b k) id]
           [`(λ (,k) (,r ,k)) #:when (η? r k) (λ (k) `(,r ,k))]
           [r                                 (λ (k) `(,r ,k))]))
       (shift-counted ctx "ctx@(shift k"
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
       (shift-counted ctx "ctx@if"
         (define (r k)
           (define kn (fk))
           (cond
             [(eq? k 'values)  (cps-if id)]
             [(symbol? k)      (cps-if (reset `(,k  ,(shift-counted k "ctx0@if-stub" k))))]
             [else `((λ (,kn) ,(cps-if (reset `(,kn ,(shift-counted k "ctx0@if-stub" k))))) ,k)]))
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
       (shift-counted ctx "ctx@((λ (x) body) rand)"
         (define d (cps0 rand))
         (match `(λ (,x) ,(cps1 body ctx))
           [`(λ (,v) ,b)      #:when (β? b v) d]
           [`(λ (,v) (,k ,v)) #:when (η? k v) `(,k ,d)]
           [k                                 `(,k ,d)]))]
      [`((λ ,x* ,body) . ,rand*)
       (shift-counted ctx "ctx@((λ x* body) . rand*)"
         (define k `(λ ,x* ,(cps1 body ctx)))
         (define d* (map cps0 rand*))
         `(,k . ,d*))]

      [`(abort . ,rand*) (cps0 `((λ (v) (shift _ v)) . ,rand*))]

      [`(,(? trivial? r) . ,rand*)
       (shift-counted ctx "ctx@平凡调用"
         (define vn (fv))
         (define d* (map cps0 rand*))
         (define r* `(,r . ,d*))
         (match `(λ (,vn) ,(ctx vn))
           [`(λ (,vn) ,b)       #:when (β? b vn) r*]
           [`(λ (,vn) (,k ,vn)) #:when (η? k vn) `(,k ,r*)]
           [k                                    `(,k ,r*)]))]

      [`(,rator . ,rand*)
       (shift-counted ctx "ctx@用户调用"
         (define vn (fv))
         (define r  (cps0 rator))
         (define d* (map cps0 rand*))
         (define r* `(,r . ,d*))
         (match `(λ (,vn) ,(ctx vn))
           [`(λ (,vn) ,b)       #:when (β? b vn) `(,r* values)]
           [`(λ (,vn) (,k ,vn)) #:when (η? k vn) `(,r* ,k)]
           [k                                    `(,r* ,k)]))]))

  (cps1 exp id))
