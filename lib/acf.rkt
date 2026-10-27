#lang racket/base
;; 「控制流的代数本质」Scribble 底本的共享写法。用法见 lib/README.md。
;;
;; 正文里的代码块原样写在 |{ … }| 里，核对工具（tools/run-blocks.rkt、tools/cmp-forms.rkt）
;; 直接读 .scrbl 源文件取出这些字符串，和 .md 时代一样按原样执行。这里只负责排版。
;;
;; 写法参照 ctp（Noah 10/26）：术语用 @deftech/@tech，公式用 Scribble 自带的 math，
;; 旁注用 @margin-note，练习写成「@bold{练习}：」开头的段落。
;; define-tech、tech/guide、tech/refer 取自 ctp 的 scribblings/ctp-utils.rkt（amb 的 utils.rkt 里也有同样的一份）。
(require (for-syntax racket/base syntax/parse)
         racket/list
         racket/string
         scribble/core
         scribble/decode
         scribble/html-properties
         (only-in scribble/manual typeset-code seclink tech deftech math)
         (only-in scribble/base linebreak hspace)
         scriblib/footnote
         (only-in scribble/example make-base-eval)
         (only-in racket/sandbox sandbox-eval-limits sandbox-memory-limit)
         racket/runtime-path)

(provide make-acf-eval
         out-block
         c mm ty
         define-tech tech/guide tech/refer
         defterm defsym glossary-table symbol-table
         xref
         (rename-out [note fn])
         acf-style chapter-style)

(define-runtime-path css-file "acf.css")

;; 挂在部的 @title 上：引入样式表。
(define acf-style
  (make-style #f (list (css-addition css-file))))
;; 挂在篇的 @title 上：每个小篇在 HTML 里单独成页。
(define chapter-style
  (make-style #f (list 'toc (css-addition css-file))))

;; ---------------------------------------------------------------------------
;; 代码里的链接
;;
;; 代码块与 @c 里的标识符按下面这些库的绑定排版：着色，并链接到它们的文档（Noah 10/26：
;; 代码层面的链接与高亮不算引用外部文档）。要链接新的库，在这里加。
;; 正文里重新定义过的名字（call/cc、label、cc……）也链接到库里对应的那一个。
(require (for-label racket/base
                    racket/function
                    racket/match
                    racket/control
                    (only-in typed/racket/base : ∀ ∪ U → case→ define-type Values Byte Real Natural Pairof)
                    control/context))
;; 同样的绑定也交给引用本模块的文档，正文里的 @racket[call/cc] 等因此能直接链接。
(provide (for-label (all-from-out racket/base racket/function racket/match racket/control control/context)
                    : ∀ ∪ U → case→ define-type Values Byte Real Natural Pairof))

(define label-context (quote-syntax here))

;; 引用其他文档的术语（取自 ctp）：@tech/refer{continuation}、@tech/guide{…}
(define-syntax (define-tech stx)
  (syntax-parse stx
    [(_ tech/name module-path)
     (syntax/loc stx
       (define (tech/name
                #:key          [key        #f]
                #:normalize?   [normalize? #t]
                #:tag-prefixes [prefixes   #f]
                #:indirect?    [indirect?  #f]
                .
                alt)
         (apply tech
                #:key          key
                #:normalize?   normalize?
                #:doc          module-path
                #:tag-prefixes prefixes
                #:indirect?    indirect?
                alt)))]))

(define-tech tech/guide '(lib "scribblings/guide/guide.scrbl"))
(define-tech tech/refer '(lib "scribblings/reference/reference.scrbl"))

;; ---------------------------------------------------------------------------
;; 求值器
;;
;; 正文的例子用 Scribble 的 @examples 写，构建文档时真的运行（照 amb 的 amb-examples）。
;; 每个小篇建自己的求值器：@(define ev (make-acf-eval))，前文假定已有的定义用
;; @examples[#:eval ev #:hidden …] 补上。代码在 typed/racket/no-check 下运行。
(define (make-acf-eval)
  (parameterize ([sandbox-eval-limits #f] [sandbox-memory-limit #f])
    (make-base-eval #:lang 'typed/racket/no-check)))

;; ---------------------------------------------------------------------------
;; 代码块
;;
;; 例子写 @examples[#:eval ev #:label #f …]：交互的例子带提示符，定义加 #:no-prompt；
;; 只排版、不求值的代码（推导、示意、不会停的程序）写 @racketblock[…]，
;; 注释写 (code:comment "…")。不带语言的输出（矩阵等）写 @out-block|{ … }|。

(define (racket-text str)
  (typeset-code #:context label-context #:keep-lang-line? #t str))

(define (body->string strs)
  (string-append* (map (λ (s) (if (string? s) s (format "~a" s))) strs)))

(define (out-block . strs)
  (nested-flow (make-style "AcfOut" '())
               (list (paragraph (make-style #f (list 'div))
                                (verbatim-lines (body->string strs))))))

(define (verbatim-lines str)
  (add-between (for/list ([line (string-split str "\n" #:trim? #f)])
                 (element 'tt (spaces->hspace line)))
               (element #f (list (linebreak)))))

(define (spaces->hspace s)
  (for/list ([piece (regexp-match* #px" +|[^ ]+" s)])
    (if (char=? (string-ref piece 0) #\space)
        (hspace (string-length piece))
        piece)))

;; ---------------------------------------------------------------------------
;; 行内

;; 行内代码：标识符与能读成一个 S 表达式的代码片段写 @racket[…]（Scribble 自带）；
;; 读不成的（如 #lang 行）写 @c{…}，按 Racket 着色并链接，和代码块一样。
(define (c . strs)
  (typeset-code #:context label-context #:block? #f #:indent 0 #:keep-lang-line? #t (body->string strs)))

;; 公式：行内直接写 Scribble 自带的 @math，照 ctp 的写法只用 Unicode，例如 @math{p ∨ ¬p}。
;; 字母排成斜体；类型名用 @ty{Label} 排成正体；代码名用 @racket[cc]。
(define (mm . content)
  (paragraph (make-style "AcfDisplayMath" '()) (apply math content)))
(define (ty . content) (element (make-style "AcfType" '()) content))

;; ---------------------------------------------------------------------------
;; 术语与符号
;;
;; @defterm[#:en "continuation"]{延续}  第一次作为术语出现：加粗，注英文，登记进术语表
;; @defterm[#:en "Double Negation Introduction" #:abbr "DNI"]{双重否定引入}
;; 之后每次出现都写 @tech{延续}，链回定义处（照 ctp）。defterm 底下就是 Scribble 的 deftech。
;; @defsym["¬p" "说明"]  在符号定义处放一个不可见的锚，登记进符号表；类型名写 @defsym[@ty{Label} "说明"]

;; 收集阶段按文档顺序把条目登记进表里，解析阶段的 delayed-block 再读出来。
;; （Scribble 的 resolve-get-keys 不带 part 时只看外部文档，所以自己记。）
(define entries (make-hash))   ; kind -> (listof (cons key vector))，倒序
(define (register! kind key val)
  (define old (hash-ref entries kind '()))
  (unless (assoc key old)
    (hash-set! entries kind (cons (cons key val) old))))
(define (collected kind) (reverse (hash-ref entries kind '())))

(define (content->key content)
  (string-normalize-spaces (content->string content)))

(define (defterm #:en [en #f] #:abbr [abbr #f] #:key [key #f] . content)
  (define k (or key (content->key content)))
  (list
   (collect-element #f '() (λ (ci) (register! 'term k (vector content en abbr))))
   (element 'bold (list (apply deftech #:key k #:style? #f content)))
   (cond [(and en abbr) (list "（" (element 'italic en) "，" abbr "）")]
         [en (list "（" (element 'italic en) "）")]
         [abbr (list "（" abbr "）")]
         [else '()])))

;; sym 可以是字符串，也可以是排版好的内容（如 @ty{Label}）；键取它的文字。
(define (defsym sym description)
  (define k (content->key (list sym)))
  (list
   (collect-element #f '() (λ (ci) (register! 'symbol k (cons sym description))))
   (target-element #f '() (list 'acf-sym k))))

;; 术语表与符号表按第一次出现的顺序排列，每项链回定义处。
(define (glossary-table)
  (delayed-block
   (λ (renderer part ri)
     (define rows
       (for/list ([entry (collected 'term)])
         (define k (car entry))
         (define v (cdr entry))
         (list (paragraph plain (apply tech #:key k (vector-ref v 0)))
               (paragraph plain (if (vector-ref v 1) (element 'italic (vector-ref v 1)) ""))
               (paragraph plain (or (vector-ref v 2) "")))))
     (table (make-style 'boxed '())
            (cons (list (paragraph plain "术语") (paragraph plain "英文") (paragraph plain "缩写"))
                  rows)))))

(define (symbol-table)
  (delayed-block
   (λ (renderer part ri)
     (define rows
       (for/list ([entry (collected 'symbol)])
         (define k (car entry))
         (define sym (cadr entry))
         (list (paragraph plain (link-element #f (math sym) (list 'acf-sym k)))
               (paragraph plain (cddr entry)))))
     (table (make-style 'boxed '())
            (cons (list (paragraph plain "符号") (paragraph plain "含义")) rows)))))

;; ---------------------------------------------------------------------------
;; 引用
;;
;; 节的标签写成 "篇号:名字"，例如 @section[#:tag "01:compare"]{比较}。
;; 回指照正文原来的说法写，链接到那一节：@xref["01:compare"]{比较一节}。
;; 篇与篇之间同样用 @xref（整个第一部是一份文档）。外部链接用 @hyperlink。
;; 文献用 scriblib/autobib（见 lib/README.md），第一篇目前没有文献引用。
(define (xref tag . content)
  (apply seclink tag content))

;; 脚注用 @fn{…}（scriblib/footnote 的 note）。旁注直接用 Scribble 的 @margin-note。
