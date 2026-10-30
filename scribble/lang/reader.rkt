#lang s-exp syntax/module-reader
;; #lang acf/scribble：scribble/manual，加上 lib/acf.rkt 的写法，并处理中文折行（Noah 10/26）。
;; 原先 .scrbl 每行限 70 栏，中文段落要折行。Scribble 会把行尾的换行排成空格，
;; 两个中文字之间就多出一个空格；这里在读入时去掉两侧都是中文字（含全角标点）的换行。
;; Noah 10/30 起中文正文每段一行，不再折行；这一步留着，手工折行时仍然管用。
acf/lib/doc-lang
#:read          scribble:read-inside
#:read-syntax   scribble:read-syntax-inside
#:whole-body-readers? #t
#:wrapper1      (lambda (t) (cons 'doc (join-cjk-lines (t))))
#:info          (scribble-base-info)
#:language-info (scribble-base-language-info)
(require (prefix-in scribble: scribble/reader)
         (only-in scribble/base/reader scribble-base-info scribble-base-language-info)
         "../../lib/cjk-join.rkt")
