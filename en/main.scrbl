#lang acf/scribble

@title[#:style acf-style]{The Algebraic Essence of Control Flow
  · Part I}

@(language-links 'en)

@;{Trial of the English edition (Noah 10/26): only the first
sub-article, written to check the layout and how two languages fit
together. The real translation waits until Part I is frozen.}

@margin-note{The code targets the latest Racket. Older versions (such
as those packaged by Linux distributions) may lack some bindings.}

@margin-note{The code runs under @c{#lang typed/racket/no-check}: the
annotations use Typed Racket syntax but are not verified by the type
checker. They are design notes describing the intended contracts, not
machine-checked assertions.}

All you need to read this book is the ability to read Scheme:
@racket[λ], @racket[let], basic recursion. Anything else is explained
where it is used. Every example was actually run when this document
was generated; the printed output and results are shown as they came
out.

@table-of-contents[]

@include-section["01-call-cc/main.scrbl"]

@section[#:tag "glossary" #:style 'unnumbered]{Glossary}

@(glossary-table #:lang 'en)

@section[#:tag "symbols" #:style 'unnumbered]{Symbols}

@(symbol-table #:lang 'en)
