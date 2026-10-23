#lang racket
;; 测试工具：编译、运行编译输出、在 Racket 中直接运行源程序
(require "cps.rkt" racket/control)
(provide show run-target run-source current-cps)
(define current-cps (make-parameter cps))

;; 目标程序：在纯 racket/base 命名空间里求值（values 等内建由 racket/base 提供）
(define (fresh-ns mods)
  (define ns (make-base-empty-namespace))
  (parameterize ([current-namespace ns])
    (for ([m mods]) (namespace-require m)))
  ns)

;; 在限时、限输出的条件下求值，返回 (list 打印 结果或错误)
(define (eval-limited expr ns #:chars [max-chars 40] #:secs [secs 2])
  (define out (open-output-string))
  (define result #f)
  (define th
    (thread
     (lambda ()
       (set! result
             (with-handlers ([exn:fail? (lambda (e) (list 'error (exn-message e)))])
               (parameterize ([current-output-port out] [current-namespace ns])
                 (call-with-values (lambda () (eval expr))
                                   (lambda vs (cons 'value vs)))))))))
  (let loop ([t 0])
    (cond
      [(thread-dead? th) (void)]
      [(or (> t (* secs 100)) (> (string-length (get-output-string out)) max-chars))
       (kill-thread th)
       (set! result (list 'killed "（未结束，已截断）"))]
      [else (sleep 0.01) (loop (add1 t))]))
  (define s (get-output-string out))
  (list (if (> (string-length s) max-chars) (string-append (substring s 0 max-chars) "...") s)
        result))

(define (run-target compiled)
  (eval-limited compiled (fresh-ns '(racket/base))))

;; 直接运行源程序：racket/base + racket/control，let/lc、abort 按第三篇定义，外面套 reset
(define src-ns
  (let ([ns (fresh-ns '(racket/base racket/control))])
    (parameterize ([current-namespace ns])
      (eval '(define-syntax-rule (let/lc k body) (shift k (k body))))
      (eval '(define (abort v) (shift _ v))))
    ns))
(define (run-source src)
  (eval-limited `(reset ,src) src-ns))

(define (show label src)
  (printf "==== ~a\n源程序:  ~s\n" label src)
  (define c (with-handlers ([exn:fail? (lambda (e) (list 'compile-error (exn-message e)))])
              ((current-cps) src)))
  (printf "编译输出: ~s\n" c)
  (match-define (list p r) (run-target c))
  (printf "目标运行: 打印 ~s  结果 ~s\n" p r)
  (match-define (list p2 r2) (run-source src))
  (printf "直接运行: 打印 ~s  结果 ~s\n\n" p2 r2))
