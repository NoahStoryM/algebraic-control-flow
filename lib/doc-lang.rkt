#lang racket/base
;; #lang acf/scribble 的模块语言：scribble/manual 与 scribble/example 的全部，加上 acf.rkt 的写法。
;; scribble/manual 自带的 defterm（斜体、不登记）让给 acf.rkt 的 defterm。
(require (except-in scribble/manual/lang defterm) scribble/example "acf.rkt")
(provide (all-from-out scribble/manual/lang)
         (all-from-out scribble/example)
         (all-from-out "acf.rkt"))
