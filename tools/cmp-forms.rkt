#lang racket
;; 用法：racket tools/cmp-forms.rkt <草稿或几节拼起来的 .md> art5-code.rkt（两个参数都要给；只给一个会退回默认的 art5-draft.md）
;; 取出草稿里所有 ```racket 定义块中的定义（define、:、define-type、struct、define-syntax-rule）；
;; 首个非空行以 > 开始的交互块只由 run-blocks.rkt 核对，
;; 逐个检查它是否（读成 S 表达式后）出现在代码文件里。right-triangles₀…₈ 视同 right-triangles。
(define-values (draft code)
  (match (current-command-line-arguments)
    [(vector d c) (values d c)]
    [_ (values "art5-draft.md" "art5-code.rkt")]))
(define (read-all-from-string str)
  ;; 「完整代码参考」在正文里带 #lang；读作普通数据时先去掉模块声明。
  (if (regexp-match? #px"^\\s*> " str)
      '() ; 交互块里的输入与打印结果不属于定义块
      (with-input-from-string (regexp-replace #px"^#lang[^\n]*\n" str "")
        (λ () (for/list ([e (in-port read)]) e)))))
(define (norm x)
  (cond [(symbol? x)
         (if (regexp-match? #rx"^right-triangles[₀₁₂₃₄₅₆₇₈]$" (symbol->string x)) 'right-triangles x)]
        [(pair? x) (cons (norm (car x)) (norm (cdr x)))]
        [else x]))
(define heads '(define : define-type struct define-syntax-rule))
(define (collect-forms x acc)
  (cond [(and (pair? x) (list? x))
         (define acc2 (if (memq (car x) heads) (set-add acc (norm x)) acc))
         (for/fold ([a acc2]) ([e x]) (collect-forms e a))]
        [else acc]))
(define code-forms
  (collect-forms (read-all-from-string (string-join (cdr (file->lines code)) "\n")) (set)))
(define blocks (regexp-match* #px"(?s:```racket\n(.*?)\n```)" (file->string draft) #:match-select cadr))
(define doc-forms
  (filter (λ (f) (and (pair? f) (memq (car f) heads)))
          (map norm (append-map read-all-from-string blocks))))
(define missing (filter (λ (f) (not (set-member? code-forms f))) doc-forms))
(printf "racket 代码块 ~a 个，定义 ~a 个，代码文件里找不到的 ~a 个\n" (length blocks) (length doc-forms) (length missing))
(for ([m missing]) (pretty-write m))
