#lang acf/scribble

@title[#:tag "01:1-labels"]{From Labels to call/cc}

@also-in['zh "01:1-labels"]

A C label is nailed into the code. What if we could pull it out, hold
it in our hands, and pass it around?

@(define ev (make-acf-eval))
@examples[#:eval ev #:hidden
(define-type ⊥ (∪))
(define primitive-call/cc call/cc)
(define (goto l) (l l))
(define (label) (primitive-call/cc goto))]

@section[#:tag "01:first-class"]{First-Class Labels}

Suppose we have first-class @tech{labels}:

@examples[#:eval ev #:label #f #:no-prompt
(define-type ⊥ (∪))  (code:comment "empty type: no constructors, no values")
(: goto  (→ Label ⊥))
(: label (→ Label))]

@racket[(label)] captures the current position in the program and
returns a @racket[Label] value. @racket[(goto l)] jumps back to where
@racket[l] was created, making that earlier call to @racket[(label)]
return once more, again handing over @racket[l]. The return type of
@racket[goto] is
@defsym["⊥" "the empty type, with no values; read as false"]@m{⊥}
(bottom), a type with no values: @racket[goto] never comes back to its
caller, because control has gone elsewhere.

“First-class” means two things. A @tech{label} is a value, like a
number or a string: it can be stored in a variable, passed to a
function, and returned as a result. And it stays valid after the
function that created it has returned, so @racket[goto] can still jump
back into that function. C's @tech{labels} can do neither.

@subsection[#:tag "01:loop"]{Loops}

@examples[#:eval ev #:label #f
(let ([x 0])
  (define loop (label))
  (set! x (add1 x))
  (when (< x 7) (goto loop))
  (displayln x))]

We capture a @tech{label} at the top of the loop body. On each
@racket[(goto loop)], execution returns to @racket[(label)], which
returns the same @tech{label} again; @racket[loop] is rebound to it,
and the body runs from the top. The mutable variable @racket[x]
records how many times we have been through.

@subsection[#:tag "01:early-return"]{Early Return}

@examples[#:eval ev #:label #f #:no-prompt
(define (mul . r*)
  (define first? #t)
  (define result (*))       (code:comment "multiplicative identity = 1")
  (define ret (label))
  (when first?
    (set! first? #f)
    (for ([r (in-list r*)])
      (when (zero? r)
        (set! result r)
        (goto ret))
      (set! result (* result r))))
  result)]

Here @racket[ret] is a “return @tech{label}”. On seeing a zero,
@racket[(goto ret)] does not jump straight to the end of the function.
Since @racket[ret] was created before the @racket[when], control goes
back to @racket[(define ret (label))] and @racket[(label)] returns
again. By now @racket[first?] is @racket[#f], the whole @racket[when]
is skipped, and the function hands over @racket[result], the zero just
stored there. The boolean flag @racket[first?] exists to tell whether
we entered for the first time or came back through @racket[goto].

@subsection[#:tag "01:label-trouble"]{The Trouble with Labels}

Both examples rely on @bold{mutating state} (@racket[set!]) to carry
information across jumps. A @tech{label} carries no data when we
@racket[(goto loop)], so we have to reach the right state through side
effects. The flag @racket[first?] in the second example has nothing to
do with multiplication: its only purpose is to answer “are we running
for the first time, or did we just jump back?”

@section[#:tag "01:cc"]{From Labels to Continuations: the @racket[cc] Operator}

The basic limitation of first-class @tech{labels} is that
@racket[goto] is a one-way ticket with no luggage. To avoid mutating
state, we need to send a value to the jump target. That is the core
idea of a @defterm{continuation}.

When @racket[(label)] is first evaluated, we would like it to return a
“callback”: a function we can call later to jump back with a value.
When that callback is called, @racket[(label)] should “return again”,
this time with the value passed in.

So the operator can return two kinds of things:

@itemlist[
  @item{A @tech{continuation} of type @m{p → ⊥}: a function that
  accepts a value of type @m{p} and never returns (it jumps back to
  the capture point).}
  @item{A value of type @m{p}, received when the @tech{continuation}
  is called.}]
We call this operator @racket[cc], short for
@racket[current-continuation]:

@examples[#:eval ev #:label #f #:no-prompt
(: cc (∀ (p) (→ (∪ p (→ p ⊥)))))
(define (cc)
  (define saved #f)
  (define l (label))
  (if saved
      (apply values saved)
      (λ args (set! saved args) (goto l))))]

@margin-note{Inside, @racket[cc] still uses @racket[label],
@racket[goto], and @racket[set!], but they are sealed off: users of
@racket[cc] no longer touch mutable state. The implementation also
handles multiple values: @racket[args] takes all the arguments and
@c{apply values} hands them all over. The type annotations in this
article leave multiple values out.}

@racket[saved] does two jobs. It is a flag: @racket[#f] means no one
has called the @tech{continuation} yet. It is also the payload: when
the @tech{continuation} is called, the arguments it receives are
stored here. The two jobs never get confused, because
@racket[(λ args …)] always collects its arguments into a list
@racket[args]; even if the argument is @racket[#f], or there are no
arguments at all, the stored list is never @racket[#f].

Follow it in time order. On the first call to @racket[(cc)],
@racket[saved] is @racket[#f], @racket[(label)] captures the current
position, @racket[if] takes the else branch and hands over a function,
the @tech{continuation}, and @racket[(cc)] returns.

Later, somewhere, this @tech{continuation} is called. It stores its
arguments in @racket[saved] and then does @racket[(goto l)] back into
@racket[cc]. By now @racket[cc] has long since returned, yet the
@tech{label} can still jump back, which is exactly the second ability
of first-class @tech{labels}. @racket[(label)] returns again and
control reaches the @racket[if] once more. This time @racket[saved] is
no longer @racket[#f]; the then branch is taken and @racket[(cc)]
returns a second time, handing over the stored value.

@subsection[#:tag "01:mul-cc"]{@racket[mul] Again}

@examples[#:eval ev #:label #f #:no-prompt
(define (mul . r*)
  (define result (cc))
  (if (real? result)
      result
      (for/fold ([res (*)] #:result (result res))
                ([r (in-list r*)])
        (if (zero? r)
            (result r)
            (* res r)))))]

@racket[for/fold] walks over @racket[r*] while accumulating
@racket[res]; @racket[#:result] says what to hand over when the walk
is done.

When @racket[(cc)] is first evaluated, @racket[result] is bound to a
@tech{continuation} (a function). A @tech{continuation} is not
@racket[real?], so we take the else branch and start folding. On a
zero we call @racket[(result r)], which triggers the
@tech{continuation}: control jumps back to where @racket[(cc)] was
evaluated, and now @racket[result] is bound to @racket[r] (a real
number). We take the then branch and return at once. With no zero, the
@racket[#:result] clause of @racket[for/fold] calls
@racket[(result res)] after the fold, which likewise triggers the
@tech{continuation}; @racket[result] is bound to the accumulated
product @racket[res] and we return from the then branch. Both paths
meet through the @tech{continuation} @racket[result], with no mutable
state and no flag.

@section[#:tag "01:call-cc"]{Eliminating the Branch: @racket[call/cc]}

@racket[cc] got rid of mutable state but brought a new requirement:
@bold{branching}. Every call to @racket[(cc)] can return two kinds of
things, and the programmer has to tell which one arrived. In the
early-return example we used @racket[(real? result)] to separate
values from @tech{continuations}. That works, but it is one more thing
for the programmer to worry about. Can we eliminate the branch as
well?

Instead of returning a union for the caller to branch on, let the
caller pass in a function @racket[proc], and hand the
@tech{continuation} to it directly as an argument. The branch moves
inside the operator, out of the user's sight.

The branch that moved inside still has to be done. The operator calls
@racket[(cc)] itself and gets the same two kinds of things: a
@tech{continuation} the first time, and the result passed back after
that. @racket[mul] could tell them apart with @racket[real?] only
because its result happened to be a real number. The operator does not
know what the result will be; it might even be a function,
indistinguishable from a @tech{continuation}. The way out is to always
wrap the result passed back in a list. A @tech{continuation} is a
function, never a list, so the two can be told apart:

@examples[#:eval ev #:label #f #:no-prompt
(: call/cc (∀ (p) (→ (→ (→ p ⊥) p) p)))
(define (call/cc proc)
  (define x (cc))
  (if (list? x)
      (apply values x)
      (proc (λ args (x args)))))]

@racket[x] is whatever @racket[(cc)] handed over; it is not the same
thing as @racket[saved] inside @racket[cc]. The first time, @racket[x]
is the @tech{continuation} of @racket[cc], not a list, so we take the
else branch. @racket[call/cc] does not hand it to @racket[proc] as is
but wraps it: @racket[(λ args (x args))] collects its arguments into a
list @racket[args] and passes that to @racket[x].

@racket[proc] receives this wrapped @tech{continuation}. If it calls
the @tech{continuation} somewhere, the @tech{continuation} of
@racket[cc] receives the list, @racket[(cc)] returns again, @racket[x]
is bound to the list, @racket[(list? x)] is true, and
@racket[(apply values x)] unpacks the list and hands it back. The
caller of @racket[call/cc] receives the values passed to the
@tech{continuation}, and whatever work remained in @racket[proc] is
skipped. If @racket[proc] returns normally without calling the
@tech{continuation}, its return value is the result of
@racket[call/cc].

With @racket[call/cc], we can write @racket[mul] once more:

@examples[#:eval ev #:label #f #:no-prompt
(define (mul . r*)
  (call/cc
   (λ (return)
     (for/fold ([res (*)])
               ([r (in-list r*)])
       (if (zero? r)
           (return r)
           (* res r))))))]

@examples[#:eval ev #:label #f
(mul 2 3 4)
(mul 2 0 3)]

The flag, the mutable state, and the @racket[real?] branch are all
gone. With no zero, @racket[for/fold] finishes normally and the
product is handed over as the return value of @racket[proc]; on a
zero, @racket[(return r)] hands the zero straight to the caller of
@racket[mul]. The @tech{continuation} now has a name: @racket[return].
The @racket[return] built into many languages is, here, an ordinary
value that @racket[call/cc] puts in our hands.

Often @racket[proc] is just a @racket[λ] like this one that gives the
current @tech{continuation} a name. A macro saves us the wrapping:

@examples[#:eval ev #:label #f #:no-prompt
(define-syntax-rule (let/cc k body ...)
  (call/cc (λ (k) body ...)))]

@racket[define-syntax-rule] defines a macro:
@racket[(let/cc k body ...)] is rewritten at expansion time into
@racket[(call/cc (λ (k) body ...))]. The body of @racket[mul] can then
be written @racket[(let/cc return …)].

@bold{Exercise}: define @racket[call/cc] using @racket[let/cc].

@subsection[#:tag "01:general-type"]{A More General Continuation Type}

The @tech{continuation} handed to @racket[proc] has type @m{p → ⊥}.
This type can be relaxed. First, a strange function:

@examples[#:eval ev #:label #f #:no-prompt
(: absurd (∀ (q) (→ ⊥ q)))
(define absurd (case-λ))]

@racket[case-λ] defines a function by cases on the number of
arguments, one clause per way of calling it. With no clauses at all,
@racket[(case-λ)] matches no call whatsoever, so the function can
never be called. That fits @m{⊥} exactly: @m{⊥} has no values, so no
one can produce one to pass in. Since the function is never called,
saying it returns any type at all cannot be wrong, so @racket[absurd]
has type @m{⊥ → q} for any @m{q}. From the empty type, anything
follows.

Put @racket[absurd] after a @tech{continuation} @racket[k], and
@racket[(compose absurd k)] has type @m{p → q}. It behaves exactly
like @racket[k]: once called, @racket[k] jumps away and
@racket[absurd] is never reached. So the @tech{continuation} handed to
@racket[proc] can also be seen as @m{p → q}, and the type of
@racket[call/cc] becomes:

@mm{((p → q) → p) → p}

Setting @m{q = ⊥} brings back the original type. The original version
says more directly what a @tech{continuation} is: a function that
receives a @m{p} and never returns.

@subsection[#:tag "01:invisible"]{The Invisible Continuation}

@racket[k] and @racket[(compose absurd k)] behave the same because
@racket[k] never returns, so nothing after it ever runs. There is a
similar equivalence inside @racket[call/cc]; the following two
expressions behave the same:

@racketblock[
(call/cc proc)
(call/cc (λ (k) (k (proc k))))]

Three things need to be kept apart here: @racket[proc] itself; the
wrapped function @racket[(λ (k) (k (proc k)))] on the second line; and
the place where the return value goes when @racket[proc] returns
normally.

First the route. The first line of @racket[call/cc],
@racket[(define x (cc))], captures a @tech{continuation}. What does
that @tech{continuation} do once it receives a value? It finishes the
@racket[if], returns from @racket[call/cc], and goes on with whatever
comes after the call to @racket[call/cc]. So it is the
@tech{continuation} of @racket[call/cc] itself, and that is also where
the @racket[k] handed to @racket[proc] leads. Now look at
@racket[(proc (λ args (x args)))]: it is in tail position in
@racket[call/cc], so when @racket[proc] returns normally, its return
value also goes straight to the @tech{continuation} of
@racket[call/cc].

So the two roads lead to the same exit. On the second line, the result
of @racket[proc] is handed over explicitly through @racket[k]; on the
first line, it gets to the same place by returning normally. What a
normal return implicitly passes through is this invisible
@tech{continuation}.

Now the types. @racket[proc] itself has type @m{(p → ⊥) → p}: it may
return a @m{p} normally, and the type of @racket[call/cc] was written
with this reading. The wrapped @racket[(λ (k) (k (proc k)))], on the
other hand, never returns normally; its result always leaves through
@racket[k], and its type is @m{(p → ⊥) → ⊥}. Handed to
@racket[call/cc], the two behave the same. We may as well require
@racket[proc] itself never to return normally, so that its type is
@m{(p → ⊥) → ⊥}. On this reading, the type of @racket[call/cc] is:

@mm{((p → ⊥) → ⊥) → p}

It takes a computation that delivers its result through a
@tech{continuation}, and pulls the result out.

@section[#:tag "01:label-from-call-cc"]{Defining Labels from @racket[call/cc]}

Let @m{p = @ty{Label}}. The @tech{continuation} that @racket[call/cc]
hands to @racket[proc] then has type @m{@ty{Label} → ⊥}, which is
exactly a @tech{label}. So @tech{labels} can be defined directly from
@racket[call/cc]:

@(define ev1 (make-acf-eval))
@examples[#:eval ev1 #:label #f #:no-prompt
(define-type Label (→ Label ⊥))
(define (goto l) (l l))
(define (label) (call/cc goto))]

@defsym[@ty{Label} "the type of labels: Label = Label → ⊥"]
@m{@ty{Label} = @ty{Label} → ⊥} is a recursive type: a @tech{label} is
a function that accepts a @tech{label} and never returns. To see what
@racket[(label)] does, unfold it step by step. Write @racket[k] for
the @tech{continuation} that @racket[call/cc] hands to @racket[goto];
it leads to the place where @racket[(label)] was called:

@racketblock[
  (label)
= (call/cc goto)
= (goto k)
= (k k)]

@racket[goto] hands @racket[k] to @racket[k] itself, so
@racket[(label)] returns @racket[k]: the @tech{label} is the
@tech{continuation} of the place where it was created. Later,
@racket[(goto l)] calls @racket[(l l)] again, jumps back to the same
place, and @racket[(label)] once more returns @racket[l]. This is
exactly the behavior described for first-class @tech{labels} at the
start.

The @racket[call/cc] here must be taken as a ready-made primitive,
such as the one built into Racket. Plugging in the @racket[call/cc] we
built from @tech{labels} earlier would go around in a circle:
@racket[label] calls @racket[call/cc], @racket[call/cc] calls
@racket[cc], and @racket[cc] calls @racket[label], forever. Defining
each other means that each one can be written with another as its
primitive, not that these definitions go into one program.

The order can also be reversed. Taking @tech{labels} as the primitive,
we first get @racket[call/cc], and from it @racket[cc]:

@(define ev2 (make-acf-eval))
@examples[#:eval ev2 #:hidden
(define primitive-call/cc call/cc)
(define (goto l) (l l))
(define (label) (primitive-call/cc goto))]
@examples[#:eval ev2 #:label #f #:no-prompt
(define (call/cc proc)
  (define saved #f)
  (define l (label))
  (if saved
      (apply values saved)
      (proc (λ args (set! saved args) (goto l)))))

(define (cc) (call/cc values))]

With no @racket[cc] at hand, this @racket[call/cc] uses @tech{labels}
and @racket[set!] directly. It is written just like @racket[cc],
except that the @tech{continuation} goes to @racket[proc] instead of
the caller. Taking @racket[cc] as the primitive, a @tech{label} is
simply the @tech{continuation} that @racket[(cc)] hands over the first
time:

@examples[#:eval ev2 #:label #f #:no-prompt
(define (label) (cc))
(define (goto l) (l l))]

Later, @racket[(goto l)] hands @racket[l] to itself, @racket[(cc)]
returns again, and what it hands over is still @racket[l]. Starting
from any one of them, the other two can be written: the three
formulations are @bold{equally expressive}.

@section[#:tag "01:compare"]{Comparison}

@tabular[#:style 'boxed #:row-properties '(bottom-border ())
  (list
   (list ""
         @elem{First-class @tech{labels}
               (@racket[goto] + @racket[label])}
         @elem{Union of value and @tech{continuation} (@racket[cc])}
         @elem{Higher-order callback (@racket[call/cc])})
   (list @elem{@bold{Types involved}}
         @elem{only @racket[Label]}
         @elem{the union @m{p ∪ (p → ⊥)}}
         @elem{higher-order: @m{((p → ⊥) → p) → p} or
               @m{((p → ⊥) → ⊥) → p}})
   (list @elem{@bold{Mutable state?}}
         @elem{yes: @racket[set!] carries information across jumps}
         @elem{no}
         @elem{no})
   (list @elem{@bold{Manual branching?}}
         @elem{no}
         @elem{yes: @m{p} and @m{p → ⊥} must be told apart}
         @elem{no}))]

The three styles can do exactly the same things, and their power has a
single source: the jump target became a value. In C, a label is a
fixed position in the code; it cannot be stored in a variable, passed
to a function, or returned. The moment a label becomes a value,
@racket[goto] gains the full power of @racket[call/cc]. Everything
after that step is a trade-off in convenience: each style pays a
different price (mutable state, branching, higher-order types) for
managing the same ability more comfortably.
