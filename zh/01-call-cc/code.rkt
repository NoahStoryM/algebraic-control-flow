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
