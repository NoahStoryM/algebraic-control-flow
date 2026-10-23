#lang racket
;; b 的补充：如果把 map 也放进平凡集合会怎样（测试用变体 cps-map-trivial.rkt）
(require (prefix-in m: "cps-map-trivial.rkt"))
(define (go src)
  (define c (m:cps src))
  (define ns (make-base-namespace))
  (parameterize ([current-namespace ns]) (eval '(define xs '(1 2))))
  (printf "源程序: ~s\n编译输出: ~s\n目标运行: ~s\n\n" src c
          (with-handlers ([exn:fail? (lambda (e) (list 'error (exn-message e)))])
            (parameterize ([current-namespace ns]) (eval c)))))
(go '(map add1 xs))
(go '(map (λ (x) (add1 x)) xs))
(go '(add1 (car (map (λ (x) (add1 x)) xs))))
