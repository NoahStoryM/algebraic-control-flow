#lang racket
;; 用法：LC_ALL=C.UTF-8 racket tools/run-blocks.rkt zh/0X-…/article.md [伪代码节标题片段 ...]
;; 若文章旁有 blocks.rktd，则按节标题与代码块开头唯一定位配置项，自动加载 prelude.rkt：
;;   (skip   (("# 节标题" "块的首行") "明确原因"))
;;   (reset  (("# 节标题" "块的首行"))) ; 从该块起重新建立命名空间并加载前置定义
;;   (stdout (("# 节标题" "块的首行") exact "打印\n")) ; 或 prefix，仅限截断输出
;;   (value  (("# 节标题" "块的首行") equal 42))
;;   (value  (("# 节标题" "块的首行") examples ("(f 1)" 2) ...))
;;   (error  (("# 节标题" "块的首行") "错误正则"))
;;   (exit   (("# 节标题" "块的首行") 0))
;; 同一节中首行重复时，选择器可以继续包含后续行，直到唯一匹配。
;; 不带 blocks.rktd 的第五篇沿用以下原有规则。
;; 定义块照文件逐式执行；交互块以首个非空行的 > 提示符识别，
;; 逐项核对打印、返回值和错误。纯推导等式保留 racket 围栏，必要时用配置跳过。
;; 无 blocks.rktd 的旧稿还接受「表达式 / ;; => / 字面量」结果对。
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
(define (blocks-of s)
  (regexp-match* #px"(?s:```racket\n(.*?)\n```)" s #:match-select cadr))
(define (interactive? b)
  (regexp-match? #px"^\\s*> " b))
(struct repl (input output) #:transparent)
(define (complete-form s)
  (with-handlers ([exn:fail:read:eof? (λ (_) #f)])
    (with-input-from-string s
      (λ ()
        (define value (read))
        (and (not (eof-object? value))
             (eof-object? (read))
             (cons value #t))))))
(define (repl-forms b)
  (define commands '())
  (define input #f)
  (define printed '())
  (define ready? #f)
  (define (finish)
    (when input
      (define form (complete-form input))
      (unless form (error 'repl "输入不是完整的单个表达式：~s" input))
      (set! commands
            (cons (repl (car form) (string-join (reverse printed) "\n")) commands)))
    (set! input #f)
    (set! printed '())
    (set! ready? #f))
  (for ([line (string-split b "\n" #:trim? #f)])
    (cond [(string-prefix? line "> ")
           (finish)
           (define source (substring line 2))
           (unless (regexp-match? #px"^\\s*;" source)
             (set! input source)
             (set! ready? (and (complete-form input) #t)))]
          [(not input)
           (unless (string=? (string-trim line) "")
             (error 'repl "交互块的首行应有 > 提示符：~s" line))]
          [ready? (set! printed (cons line printed))]
          [else
           (set! input (string-append input "\n" line))
           (set! ready? (and (complete-form input) #t))]))
  (finish)
  (reverse commands))
(define (forms-of b)
  (if (interactive? b)
      (repl-forms b)
      (for/list ([e (in-port read (open-input-string (regexp-replace* #rx";; =>" b " =>> ")))]) e)))
(define (evaluate-repl form)
  (define out (open-output-string))
  (define err #f)
  (parameterize ([current-output-port out])
    (with-handlers ([exn:fail? (λ (e) (set! err (exn-message e)))])
      (call-with-values (λ () (eval form))
        (λ vs
          (for ([v vs] #:unless (void? v))
            (print v out)
            (newline out))))))
  (values (get-output-string out) err))
(define (check-repl command)
  (define-values (actual err) (evaluate-repl (repl-input command)))
  (define expected (repl-output command))
  (define comparable
    (if err
        (string-append actual "; " (regexp-replace* #rx"\n" err "\n; ") "\n")
        actual))
  (define prefix? (string-suffix? expected "..."))
  (define target (if prefix? (substring expected 0 (- (string-length expected) 3)) expected))
  (define expected-datum (and (not prefix?) (complete-form target)))
  (define actual-datum (and (not err) expected-datum (complete-form comparable)))
  (unless (or (and prefix? (string-prefix? comparable target))
              (and actual-datum (equal? (car actual-datum) (car expected-datum)))
              (and (not prefix?)
                   (string=? comparable (if (string=? target "") "" (string-append target "\n")))))
    (error 'repl "~s: ~s vs ~s" (repl-input command) comparable expected)))
(define article-path (vector-ref (current-command-line-arguments) 0))
(define config-path (build-path (path-only (path->complete-path article-path)) "blocks.rktd"))
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
          [(list (? repl? command) rest ...)
           (with-handlers ([exn:fail?
                            (λ (x) (if strict? (raise x)
                                       (set! clean? #f)))])
             (check-repl command)
             (set! ok (add1 ok)))
           (loop rest last)]
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

(define (setup-namespace [prelude #f])
  (define new-ns (make-base-namespace))
  (parameterize ([current-namespace new-ns])
    (eval '(require typed/racket/no-check racket/list racket/match racket/control racket/contract))
    (eval '(define ∘ compose))
    (eval '(define-syntax-rule (match-λ clause ...) (match-lambda clause ...)))
    (when prelude (load prelude)))
  new-ns)

;; 带配置的文章按「节标题 + 块首行」定位。一个选择器必须恰好指向一个块；
;; 插入其他块不会改变配置的含义。
(struct block (section first source) #:transparent)
(define (configured-blocks)
  (for/list ([sec sections])
    (cons (title-of sec)
          (for/list ([b (blocks-of sec)])
            (block (title-of sec)
                   (let ([ls (filter (λ (s) (not (string=? s ""))) (map string-trim (string-split b "\n")))])
                     (if (null? ls) "" (car ls)))
                   b)))))
(define (run-configured)
  (define all-sections (configured-blocks))
  (define all-blocks (append* (map cdr all-sections)))
  (define cfg (call-with-input-file config-path read))
  (define entries (make-hash))
  (for ([group cfg])
    (match group
      [(list (? symbol? kind) entry ...)
       (unless (memq kind '(skip reset value stdout error exit))
         (error 'config "未知配置项：~s" kind))
       (for ([item entry])
         (match item
           [(list (list (? string? section) (? string? first)) arg ...)
            (define found
              (filter (λ (b)
                        (define normalized
                          (string-join (map string-trim (string-split (block-source b) "\n")) "\n"))
                        (and (string=? section (block-section b))
                             (or (string=? normalized first)
                                 (string-prefix? normalized (string-append first "\n")))))
                      all-blocks))
            (unless (= (length found) 1)
              (error 'config "~s / ~s 匹配到 ~a 个代码块，要求恰好一个" section first (length found)))
            (define b (car found))
            (when (hash-has-key? entries (cons kind b))
              (error 'config "重复配置 ~s：~s" kind first))
            (hash-set! entries (cons kind b) arg)]
           [_ (error 'config "配置格式错误：~s" item)]))]
      [_ (error 'config "配置格式错误：~s" group)]))
  (define (setting kind b [default #f]) (hash-ref entries (cons kind b) default))
  (define prelude (build-path (path-only config-path) "prelude.rkt"))
  (define current-ns (setup-namespace (and (file-exists? prelude) prelude)))
  (define checked 0)
  (define skipped 0)
  (define equations 0)
  ;; 延续会恢复定义时的输出端口；各块共用一个端口，每块开始时清空缓冲。
  (define output (open-output-bytes))
  (define (captured-output) (bytes->string/utf-8 (get-output-bytes output)))
  (define (evaluate b strict?)
    (when (and strict? (getenv "TRACE_BLOCKS"))
      (eprintf "rerun ~a / ~a\n" (block-section b) (block-first b)))
    (define input (block-source b))
    (define result (void))
    (get-output-bytes output #t)
    (define expected-error (setting 'error b))
    (define expected-exit (setting 'exit b))
    (define expected-out (setting 'stdout b))
    (define failed #f)
    (define ok 0)
    (define exit-status #f)
    (parameterize ([current-namespace current-ns]
                   [current-output-port output]
                   [exit-handler (λ (status) (raise (list 'controlled-exit status)))])
      (let loop ([fs (forms-of input)])
        (match fs
          ['() (void)]
          [(list (? repl? command) rest ...)
           (if (or expected-out expected-exit)
               (with-handlers
                   ([(λ (x) (and (pair? x) (eq? (car x) 'controlled-exit)))
                     (λ (x) (set! exit-status (cadr x)))]
                    [exn:fail:contract:variable?
                     (λ (x) (if strict? (raise x) (set! failed #t)))])
                 (set! result (eval (repl-input command))))
               (begin (check-repl command) (set! ok (add1 ok))))
           (unless (or failed exit-status) (loop rest))]
          [(list '=>> expected rest ...)
           (cond
             [failed (void)]
             [(equal? result (eval expected)) (set! ok (add1 ok))]
             [else (error 'mismatch "~a / ~a: ~s vs ~s"
                          (block-section b) (block-first b) result expected)])
           (loop rest)]
          [(list e rest ...)
           (with-handlers
               ([(λ (x) (and (pair? x) (eq? (car x) 'controlled-exit)))
                 (λ (x) (set! exit-status (cadr x)))]
                [exn:fail:contract:variable?
                 (λ (x) (if strict? (raise x) (set! failed #t)))]
                [exn:fail?
                 (λ (x)
                   (cond
                     [(and (not strict?)
                           (regexp-match? #rx"(undefined|unbound identifier|cannot reference an identifier)"
                                          (exn-message x)))
                      (set! failed #t)]
                     [expected-error
                       (begin
                         (unless (regexp-match? (regexp (car expected-error)) (exn-message x))
                           (error 'mismatch "错误信息不符：~a / ~a: ~a"
                                  (block-section b) (block-first b) (exn-message x)))
                         (set! expected-error #f)
                         (set! ok (add1 ok)))]
                     [else (raise x)]))])
             (set! result (eval e)))
           (unless (or exit-status failed)
             (loop rest))])))
    (when (and (not failed) expected-error)
      (error 'mismatch "预期的错误没有发生：~a / ~a" (block-section b) (block-first b)))
    (when (and (not failed) expected-exit)
      (unless (equal? exit-status (car expected-exit))
        (error 'mismatch "退出状态不符：~a / ~a: ~s"
               (block-section b) (block-first b) exit-status))
      (set! ok (add1 ok)))
    (when (and (not failed) exit-status (not expected-exit))
      (error 'config "未配置的 exit：~a / ~a" (block-section b) (block-first b)))
    (when (and (not failed) expected-out)
      (when (interactive? input)
        (define shown
          (apply string-append
                 (for/list ([command (repl-forms input)]
                            #:unless (string=? (repl-output command) ""))
                   (string-append (repl-output command) "\n"))))
        (when (and (eq? (car expected-out) 'exact)
                   (not (string=? shown (cadr expected-out))))
          (error 'config "交互块展示与 stdout 配置不符：~a / ~a"
                 (block-section b) (block-first b))))
      (match expected-out
        [(list 'exact s)
         (unless (string=? (captured-output) s)
           (error 'mismatch "打印不符：~a / ~a: ~s vs ~s"
                  (block-section b) (block-first b) (captured-output) s))]
        [(list 'prefix s)
         (unless (string-prefix? (captured-output) s)
           (error 'mismatch "打印前缀不符：~a / ~a" (block-section b) (block-first b)))]
        [_ (error 'config "stdout 只接受 exact/prefix：~s" expected-out)])
      (set! ok (add1 ok)))
    (define expected-value (setting 'value b))
    (when (and (not failed) expected-value)
      (match expected-value
        [(list 'equal v)
         (unless (equal? result v)
           (error 'mismatch "结果不符：~a / ~a: ~s vs ~s"
                  (block-section b) (block-first b) result v))]
        [(list 'examples checks ...)
         (for ([check checks])
           (match check
             [(list (? string? expression) expected)
              (define actual (parameterize ([current-namespace current-ns])
                               (eval (read (open-input-string expression)))))
              (unless (equal? actual expected)
                (error 'mismatch "样例不符：~a / ~a: ~s => ~s vs ~s"
                       (block-section b) (block-first b) expression actual expected))]
             [_ (error 'config "examples 的每项应为 (表达式字符串 结果)：~s" check)]))]
        [_ (error 'config "value 只接受 equal/examples：~s" expected-value)])
      (set! ok (+ ok (if (eq? (car expected-value) 'examples)
                         (sub1 (length expected-value))
                         1))))
    (when (and (not failed) (not expected-out)
               (not (string=? (captured-output) "")))
      (error 'config "有打印但未配置 stdout：~a / ~a: ~s"
             (block-section b) (block-first b) (captured-output)))
    (values failed ok))
  (for ([section all-sections])
    (define bs (cdr section))
    (for ([b bs])
      (define reset-to (setting 'reset b))
      (when reset-to
        (unless (null? reset-to) (error 'config "reset 不接受额外参数：~s" reset-to))
        (set! current-ns (setup-namespace (and (file-exists? prelude) prelude))))
      (cond
        [(setting 'skip b)
         (when (for/or ([kind '(value stdout error exit)]) (setting kind b))
           (error 'config "跳过的块不能同时配置结果：~a / ~a"
                  (block-section b) (block-first b)))
         (unless (and (= (length (setting 'skip b)) 1)
                      (non-empty-string? (car (setting 'skip b))))
           (error 'config "skip 要写原因：~s" b))
         (set! skipped (add1 skipped))]
        [(and (not (regexp-match? #px"^#lang" (block-source b)))
              (memq '= (forms-of (block-source b))))
         (set! equations (add1 equations))]
        [else
         (define-values (_ ok)
           (with-handlers ([exn:fail?
                            (λ (x) (error 'run-blocks "~a / ~a: ~a"
                                          (block-section b) (block-first b)
                                          (exn-message x)))])
             (evaluate b #t)))
         (set! checked (+ checked ok))])))
  (printf "代码块 ~a 个（等式块 ~a，配置跳过 ~a），核对 ~a 处\n"
          (length all-blocks) equations skipped checked))

(define (run-legacy)
  (parameterize ([current-namespace ns])
    (eval '(require typed/racket/no-check racket/list racket/match racket/control))
    (eval '(define ∘ compose))
    (eval '(define-syntax-rule (match-λ clause ...) (match-lambda clause ...)))
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
          (if (zero? n-pseudo) "" (format "；伪代码节 ~a 节（不执行）" n-pseudo))))
(if (file-exists? config-path) (run-configured) (run-legacy))
