#lang racket
(provide output-starts-with?)

;; 为故意不终止的例子只观察有限前缀；运行者总在独立 custodian 中停止。
(define (output-starts-with? thunk prefix #:seconds [seconds 2])
  (define out (open-output-string))
  (define cust (make-custodian))
  (define failure #f)
  (define worker
    (parameterize ([current-custodian cust])
      (thread
       (λ ()
         (with-handlers ([exn:fail? (λ (e) (set! failure e))])
           (parameterize ([current-output-port out])
             (thunk)))))))
  (define deadline (+ (current-inexact-milliseconds) (* seconds 1000)))
  (define answer
    (let loop ()
      (define seen (get-output-string out))
      (cond [(>= (string-length seen) (string-length prefix))
             (string-prefix? seen prefix)]
            [(or failure (thread-dead? worker)
                 (>= (current-inexact-milliseconds) deadline))
             #f]
            [else (sleep 0.01) (loop)])))
  (custodian-shutdown-all cust)
  (when failure (raise failure))
  answer)
