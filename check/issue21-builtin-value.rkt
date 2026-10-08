#lang racket
;; 仅修 #21 的实测；原来的 check/ 记录保持不动。
(require rackunit racket/runtime-path
         (prefix-in original: "cps.rkt")
         (prefix-in final: "../zh/04-compiler/code.rkt")
         "harness.rkt")

(define-runtime-path examples "step1-article-examples.rkt")
(define example-forms
  (call-with-input-file examples
    (λ (in)
      (read-line in) ; 跳过 #lang
      (for/list ([form (in-port read in)]
                 #:when (and (pair? form) (eq? (car form) 'show)))
        form))))
(displayln "原文例子的编译输出（按 ~s 打印逐字比较）")
(for ([form example-forms])
  (define label (second form))
  (define source (second (third form)))
  (check-equal? (format "~s" (final:cps source))
                (format "~s" (original:cps source)) label)
  (printf "~a：不变\n" label))
(printf "共 ~a 例\n\n" (length example-forms))

(current-cps final:cps)
(for ([label '(a1 a2 a3 b1 b2 b3)]
      [source '((let ([f add1]) (f 41))
                (let ([g add1]) (g 1))
                (reset (let ([f add1]) (+ 1 (f 41))))
                ((λ (h) (h 1)) add1)
                ((λ (h x) (h x)) add1 1)
                (let ([twice (λ (h x) (h (h x)))]) (twice add1 1)))])
  (show label source))

(displayln "已知代价（本次不修）")
(show "内建函数的对象身份" '(eq? add1 add1))
(show "内建函数的打印名" '(display add1))
(define map-source '(map add1 xs))
(define map-code (final:cps map-source))
(define map-ns (make-base-namespace))
(parameterize ([current-namespace map-ns])
  (eval '(define xs '(1 2)))
  (printf "map 源程序: ~s\nmap 编译输出: ~s\n" map-source map-code)
  (printf "map 直接运行: ~s\n" (eval map-source))
  (printf "map 目标运行: ~s\n"
          (with-handlers ([exn:fail? (λ (e) (exn-message e))])
            (eval map-code))))

(displayln "\n#22 的 reset 求值顺序保持原样")
(define order-source '(eq? (reset (display 1)) (display 2)))
(check-equal? (final:cps order-source) (original:cps order-source))
(show "reset 在前" order-source)
