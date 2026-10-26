#lang acf/scribble

@title[#:tag "01" #:style chapter-style]{When Labels Become Logic:
  Demystifying call/cc}

@also-in['zh "01"]

@racket[call-with-current-continuation] (@racket[call/cc] for short)
is one of the most powerful, and most feared, control operators in the
Scheme tradition. It is often called “a glorified goto”, and that
claim can be tested literally. C's @tt{goto} can only jump to a
@defterm{label} written into the code. If a @tech{label} were itself a
value, something you could store in a variable or return from a
function, it would be a first-class value. Starting from such
@tech{labels}, how far are we from @racket[call/cc]?

@include-section["1-labels.scrbl"]
