#lang racket
;; 用法：racket tools/run-blocks.rkt <某一节或几节拼起来的 .md>（路径含中文时先复制成英文文件名）
;; 照原样执行代码块；每个「表达式 / ;; => / 字面量」对，检查求值结果与写出的字面量 equal?
;;
;; 不执行的块：
;;   等式块：顶层出现单独的 = （「左边 = 右边」，带 e、body 这样的占位名字）。
;; 先用后定义（一节之内）：
;;   一节可以先展示行为、后给实现（例如先演示 amb，节末才用 choose 定义它）。
;;   按「# 」标题把文件分成节；某一节第一遍执行时若碰到未定义的名字或结果对不上，
;;   这一节整个重跑第二遍（这时节内的定义都已经有了），第二遍必须全部通过。
;;   第二遍仍然用到未定义名字的顶层表达式是伪代码（先写出想要的程序）：
;;   它不能带 ;; => 的结果，并且必须原样出现在本节后面某个能执行的式子里，否则报错。
;; 伪代码节（整节都是想要的写法，实现在后面的节里）：
;;   在文件名后面再给参数，每个是一节标题里的一段字，例如  racket tools/run-blocks.rkt all.md 描述关系的语言
;;   这样的节不执行，也不许带 ;; => 的结果。其中的定义交给 cmp-forms 去和代码文件核对（代码文件里原样运行）；
;;   不是定义的顶层式子（例如照抄前文的一段程序），必须原样出现在本文件别的节里。
;;   参数里有中文，要在 UTF-8 的区域设置下运行（LC_ALL=C.UTF-8 racket …），否则参数被读成问号，一节也对不上；对不上时报错。
(define ns (make-base-namespace))
(define src (file->string (vector-ref (current-command-line-arguments) 0)))
(define sections (filter (λ (s) (not (string=? s ""))) (regexp-split #px"(?m:^(?=# ))" src)))
(define pseudo-titles (cdr (vector->list (current-command-line-arguments))))
(define (title-of sec) (car (string-split sec "\n")))
(define (pseudo-section? sec) (for/or ([t pseudo-titles]) (string-contains? (title-of sec) t)))
(for ([t pseudo-titles])
  (unless (for/or ([sec sections]) (string-contains? (title-of sec) t))
    (error 'run-blocks "没有哪一节的标题含有「~a」（中文参数要在 LC_ALL=C.UTF-8 下运行）" t)))
(define (blocks-of s) (regexp-match* #px"(?s:```racket\n(.*?)\n```)" s #:match-select cadr))
(define (forms-of b)
  (for/list ([e (in-port read (open-input-string (regexp-replace* #rx";; =>" b " =>> ")))]) e))
(define (subterm? x y) (or (equal? x y) (and (pair? y) (or (subterm? x (car y)) (subterm? x (cdr y))))))
(define n-blocks 0) (define n-eq 0) (define n-ok 0) (define n-rerun 0) (define n-pseudo 0)
(define def-heads '(define : define-type struct define-syntax-rule define-syntax))
;; 伪代码节：不执行。回报其中「不是定义」的顶层式子，它们要在别的节里原样出现
(define (check-pseudo-section sec others)
  (define other-forms (append* (for/list ([o others]) (append* (map forms-of (blocks-of o))))))
  (for ([b (blocks-of sec)])
    (define forms (forms-of b))
    (when (memq '=>> forms) (error 'pseudo "伪代码节里不能带结果：~a" (title-of sec)))
    (unless (memq '= forms)
      (for ([e forms])
        (unless (and (pair? e) (memq (car e) def-heads))
          (unless (for/or ([f other-forms]) (subterm? e f))
            (error 'pseudo "伪代码节 ~a 里的式子没有在别的节原样出现：~s" (title-of sec) e))))))
  (set! n-pseudo (add1 n-pseudo)))

;; 执行一节。strict? 为假：碰到问题只回报 #f；为真：问题就是错误（伪代码除外）。回报 (values 干净? 核对数 伪代码数)
(define (run-section sec strict?)
  (define clean? #t) (define ok 0) (define pending '()) (define pseudo 0)
  (define failed (gensym))
  (for ([b (blocks-of sec)])
    (define forms (forms-of b))
    (unless (memq '= forms)
      (let loop ([fs forms] [last (void)])
        (match fs
          ['() (void)]
          [(list '=>> expected rest ...)
           (cond [(eq? last failed)
                  (when strict? (error 'pseudo "带结果的式子用到了未定义的名字：~s" expected))
                  (set! clean? #f)]
                 [(equal? last (eval expected)) (set! ok (add1 ok))]
                 [strict? (error 'mismatch "~s vs ~s" last expected)]
                 [else (set! clean? #f)])
           (loop rest last)]
          [(list e rest ...)
           (define v (with-handlers ([exn:fail:contract:variable? (λ (x) failed)]) (eval e)))
           (set! pending (filter (λ (p) (not (subterm? p e))) pending))
           (when (eq? v failed)
             (set! clean? #f)
             (set! pending (cons e pending)))
           (loop rest v)]))))
  (when (and strict? (pair? pending))
    (error 'pseudo "用到了未定义的名字，本节后面也没有原样兑现：~s" pending))
  (values clean? ok pseudo))

(parameterize ([current-namespace ns])
  (eval '(require typed/racket/no-check racket/list racket/match racket/control))
  (eval '(define ∘ compose))   ; 前文（第二篇）的定义
  (eval '(define-syntax-rule (match-λ clause ...) (match-lambda clause ...)))   ; 第四篇用过；Racket 8.10 的 racket/match 还没有
  (for ([sec sections])
    (define bs (blocks-of sec))
    (set! n-blocks (+ n-blocks (length bs)))
    (set! n-eq (+ n-eq (count (λ (b) (memq '= (forms-of b))) bs)))
    (define-values (clean? ok _p)
      (if (pseudo-section? sec)
          (begin (check-pseudo-section sec (remq sec sections)) (values #t 0 0))
          (run-section sec #f)))
    (cond [clean? (set! n-ok (+ n-ok ok))]
          [else
           (set! n-rerun (add1 n-rerun))
           (define-values (_c ok2 _p2) (run-section sec #t))
           (set! n-ok (+ n-ok ok2))])))
(printf "代码块 ~a 个（其中等式块 ~a 个，不执行），核对的结果 ~a 处，全部一致；先用后定义、重跑了一遍的有 ~a 节~a\n"
        n-blocks n-eq n-ok n-rerun
        (if (zero? n-pseudo) "" (format "；伪代码节 ~a 节（不执行）" n-pseudo)))
