#lang racket
;; 核对一篇从 .md 转成 .scrbl 之后，正文文字与代码有没有走样（#47 的验收办法）。
;;
;; 用法：LC_ALL=C.UTF-8 racket tools/cmp-conversion.rkt zh/0X-…/article.md zh/0X-…/main.scrbl
;;
;; 做法：在进程内用 Scribble 的文本渲染器把 .scrbl 排成纯文本，再把 .md 去掉标记，
;; 两边都删去所有空白后比较。.md 按段落（空行分隔，代码块整块算一段）逐段到 .scrbl 的文本里找，
;; 找到就划掉，所以段落挪了位置不算差异。最后报告两样东西：
;;   1. .md 里在 .scrbl 中找不到的段落（文字改了或丢了）；
;;   2. .scrbl 里没被划掉的剩余文字（新加的文字）。节号「1.2.1.」这类排版产物不报。
;; 删空白比较看不出代码缩进的变化，所以代码块另外逐字比较：.md 的每个代码块
;; 要和 .scrbl（跟着 @include-section，见 scrbl-source.rkt）里某个代码块的内容一字不差。
;; 有找不到的段落或代码块时返回非零状态。
(require scribble/render
         setup/xref
         (prefix-in text: scribble/text-render)
         "scrbl-source.rkt")

;; (listof (cons 'text|'code 字符串))
(define (md-paragraphs text)
  (define paras '())
  (define cur '())
  (define fence #f)
  (define (push! kind lines)
    (set! paras (cons (cons kind (string-join (reverse lines) "\n")) paras)))
  (for ([line (string-split text "\n" #:trim? #f)])
    (cond [fence
           (if (string-prefix? line "```")
               (begin (push! 'code fence) (set! fence #f))
               (set! fence (cons line fence)))]
          [(string-prefix? line "```")
           (unless (null? cur) (push! 'text cur) (set! cur '()))
           (set! fence '())]
          [(string=? (string-trim line) "")
           (unless (null? cur) (push! 'text cur) (set! cur '()))]
          [else (set! cur (cons line cur))]))
  (unless (null? cur) (push! 'text cur))
  (reverse paras))

(define (strip-md-line line)
  (let* ([line (regexp-replace #px"^#+ " line "")]
         [line (regexp-replace #px"^>\\s?" line "")]   ; 引用框（代码块外的 > 只会是它）
         [m (regexp-match #px"^(\\d+\\.|-) " line)]
         ;; scribble 的文本渲染里列表项都以 * 开头
         [bullet (if m "* " "")]
         [line (if m (substring line (string-length (car m))) line)]
         [line (regexp-replace* #px"\\[([^\\]]*)\\]\\([^)]*\\)" line "\\1")])
    ;; 行内代码原样保留，其余部分去掉强调记号、公式记号与表格竖线
    (string-append
     bullet
     (string-append*
      (for/list ([part (regexp-match* #px"`[^`]*`|[^`]+|`" line)])
        (if (and (> (string-length part) 1) (char=? (string-ref part 0) #\`))
            (substring part 1 (sub1 (string-length part)))
            (regexp-replace* #px"[*$|]" part "")))))))

(define (strip-md p)
  (string-join
   (for/list ([line (string-split p "\n" #:trim? #f)]
              #:unless (and (regexp-match? #px"^\\s*\\|?[\\s|:-]+\\|?\\s*$" line)   ; 表格分隔行
                            (string-contains? line "-"))
              #:unless (string=? (string-trim line) "---"))
     (strip-md-line line))
   "\n"))

;; \s 只认 ASCII 空白；Scribble 的文本输出里还有不换行空格等，一并删去
(define (squash s) (regexp-replace* #px"(?:\\s|\\p{Z})+" s ""))

(define (scribble-text scrbl)
  (define dir (make-temporary-directory))
  (dynamic-wind
   void
   (λ ()
     (define doc (dynamic-require (path->complete-path scrbl) 'doc))
     (parameterize ([current-output-port (open-output-nowhere)])
       (render (list doc) (list "out") #:dest-dir dir #:render-mixin text:render-mixin
               #:xrefs (list (load-collections-xref))))
     (file->string (build-path dir "out.txt")))
   (λ () (delete-directory/files dir))))

(define (scrbl-code scrbl)
  (for*/list ([sec (scrbl-sections scrbl)] [b (cdr sec)]) (sblock-source b)))

(define (main md scrbl)
  (define paras (md-paragraphs (file->string md)))
  (define text
    (regexp-replace* #px"\\\\[()\\[\\]]" (scribble-text scrbl) ""))   ; 公式的 \( \) \[ \]
  (define pool (regexp-replace* #px"-{5,}" (squash text) ""))           ; 表头下的横线
  (define missing '())
  (for ([p paras])
    (define q (squash (if (eq? (car p) 'code) (cdr p) (strip-md (cdr p)))))
    (unless (string=? q "")
      (define pos (let ([m (regexp-match-positions (regexp-quote q) pool)]) (and m (caar m))))
      (if pos
          (set! pool (string-append (substring pool 0 pos) "\0" (substring pool (+ pos (string-length q)))))
          (set! missing (cons (cdr p) missing)))))
  (define left
    (filter non-empty-string?
            (for/list ([x (string-split pool "\0" #:trim? #f)])
              (regexp-replace #px"^\\d+(\\.\\d+)*\\.?" x ""))))
  (define codes (scrbl-code scrbl))
  (define md-codes (for/list ([p paras] #:when (eq? (car p) 'code)) (cdr p)))
  (define code-missing (filter (λ (c) (not (member c codes))) md-codes))
  (define code-extra (filter (λ (c) (not (member c md-codes))) codes))
  (printf "代码块：md ~a 个，scrbl ~a 个；md 有而 scrbl 没有的 ~a 个，scrbl 多出的 ~a 个\n"
          (length md-codes) (length codes) (length code-missing) (length code-extra))
  (for ([c (append code-missing code-extra)])
    (printf "  ! ~a\n" (string-replace c "\n" "\n    ")))
  (define all-missing (append (reverse missing) code-missing))
  (printf "md 里找不到的段落：~a\n" (length all-missing))
  (for ([p all-missing])
    (define s (string-replace p "\n" "\n    "))
    (printf "  - ~a\n" (substring s 0 (min 400 (string-length s)))))
  (printf "scrbl 里多出的文字：~a 处\n" (length left))
  (for ([x left]) (printf "  + ~a\n" (substring x 0 (min 400 (string-length x)))))
  (unless (null? all-missing) (exit 1)))

(module+ main
  (match (current-command-line-arguments)
    [(vector md scrbl) (main md scrbl)]
    [_ (eprintf "用法：racket tools/cmp-conversion.rkt <article.md> <main.scrbl>\n") (exit 2)]))
