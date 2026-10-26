#lang racket
;; 从 .scrbl 源文件取出正文的代码，供 run-blocks.rkt 与 cmp-forms.rkt 使用。
;;
;; 不执行文档，只用 Scribble 的 @-读取器把源文件读成数据，按文档顺序找：
;;   @title / @section     分节
;;   @include-section[…]   跟着读进被包含的文件（相对路径），篇的 main.scrbl 由此串起各小篇
;;   @examples[…]          构建时求值的例子（照 amb 的 amb-examples）；#:hidden 的是补前提的隐藏定义
;;   @racketblock[…]       只排版、不求值的代码（推导、示意、无限循环的程序）
;;   @out-block|{…}|       不带语言的输出（矩阵等）
;; 例子里的 (code:comment …)、(code:blank) 去掉；(eval:alts 显示的 求值的) 取显示的那一个。
(require scribble/reader)
(provide (struct-out sblock) scrbl-sections strip-code-annotations)

;; kind：'examples 'racketblock 'out；forms：S 表达式的列表（'out 时是字符串）；
;; opts：关键字参数（如 #:hidden、#:eval）组成的散列表
(struct sblock (kind forms opts file) #:transparent)

(define section-heads '(title section))

(define (read-scrbl path)
  (define text (file->string path))
  (define body (regexp-replace #px"^#lang[^\n]*\n" text ""))
  (define in (open-input-string body))
  (port-count-lines! in)
  (read-inside in))

;; @examples 的这些关键字不带值
(define flag-keywords
  '(#:hidden #:no-prompt #:no-result #:no-inset #:result-only #:preserve-source-locations #:once))

;; 去掉关键字参数，返回 (values 关键字表 其余参数)；不带值的关键字记为 #t
(define (split-keywords args)
  (let loop ([args args] [kws '()] [rest '()])
    (match args
      ['() (values (reverse kws) (reverse rest))]
      [(list (? keyword? k) more ...)
       #:when (memq k flag-keywords)
       (loop more (cons (cons k #t) kws) rest)]
      [(list (? keyword? k) v more ...) (loop more (cons (cons k v) kws) rest)]
      [(list x more ...) (loop more kws (cons x rest))])))

(define (flatten-text x)
  (cond [(string? x) x]
        [(and (pair? x) (symbol? (car x)))
         (define-values (_ args) (split-keywords (cdr x)))
         (string-append* (map flatten-text args))]
        [(list? x) (string-append* (map flatten-text x))]
        [else ""]))

(define (strip-code-annotations x)
  (match x
    [(list 'eval:alts shown _) (strip-code-annotations shown)]
    [(list (or 'code:comment 'code:blank) _ ...) (void)]
    [(? list?) (for/list ([e x] #:unless (void? (strip-code-annotations e)))
                 (strip-code-annotations e))]
    [(cons a b) (cons (strip-code-annotations a) (strip-code-annotations b))]
    [_ x]))

;; 返回 (listof (cons 节标题 (listof sblock)))，按文档顺序；跨文件连续。
(define (scrbl-sections main)
  (define sections '())          ; 倒序
  (define current-title #f)
  (define current-blocks '())
  (define (flush!)
    (when (or current-title (pair? current-blocks))
      (set! sections (cons (cons (or current-title "") (reverse current-blocks)) sections)))
    (set! current-blocks '()))
  (define (walk-file path)
    (define dir (path-only (path->complete-path path)))
    (for ([x (read-scrbl path)]) (walk x dir path)))
  (define (add! kind forms kws file)
    (set! current-blocks
          (cons (sblock kind forms (for/hash ([kw kws]) (values (car kw) (cdr kw))) file)
                current-blocks)))
  (define (walk x dir file)
    (when (and (pair? x) (symbol? (car x)))
      (define head (car x))
      (define-values (kws args) (split-keywords (cdr x)))
      (case head
        [(title section) (flush!) (set! current-title (flatten-text args))]
        [(include-section) (walk-file (build-path dir (car args)))]
        [(examples) (add! 'examples (filter pair? (map strip-code-annotations args)) kws file)]
        [(racketblock) (add! 'racketblock (filter (λ (f) (not (void? f)))
                                                  (map strip-code-annotations args))
                             kws file)]
        [(out-block) (add! 'out (string-append* args) kws file)]
        [else (for ([y (cdr x)]) (walk y dir file))])))
  (walk-file main)
  (flush!)
  (reverse sections))
