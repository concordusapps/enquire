'use strict'

parser = require \../lib/parser.js

# Check if an object is empty.
empty = ->
  for _ of it => return false
  true

# Map up the arity with an operator.
arity = (op) -> match op
| (in <[ ! ]> ++ '')                      => \1
| (in <[ = != > >= < <= & &! ; concat ]>) => \2

# Map up the relation to the operator.
relation = (op) -> match op
| (is \=)  => \eq
| (is \!=) => \neq
| (is \>)  => \gt
| (is \>=) => \gte
| (is \<)  => \lt
| (is \<=) => \lte

class Inquire

  /*  Warning, this thing is chocked full of side effects.
      It's mad hard to reason about.
      Be careful...
  */

  inquiry: {}

  /*  Bound constructor allows us to call:
      LiveScript
      `Inquire!` rather than `new Inquire!`

      Javascript
      `Inquire()` rather than `new Inquire()`
  */
  (key, val, {bool=\& rel=\=}={}) ~>
    options = {bool, rel}
    @_analyze key, val, options

  /*  Helper function to choose the correct string to create.
      `key` Determines the route to take depending on one of these types:
          `Inquire` -> Wrap it in parens and concat it to the previous inquire.
          `Array`   -> Join everything with the bool and concat to previous.
          `String`  -> Relate the key and val then concat to previous.
          `Object`  -> Relate each key/val, join with the bool and concat.
          Rest      -> For anything else, just throw it away.
      `val` Currently only used as the value for strings.
      `options` Additional information for constructing the inquire.
          `bool`    -> Boolean predicate to join with.
          `rel`     -> Relational operator to relate keys with values.

      Returns this Allows for chaining of inquire's.
  */
  _analyze: (key, val, {bool=\& rel=\=}={}) ->
    # We need to provide some defaults for the options and also name it.
    options = {bool, rel}
    # Figure out our path, based on what the key is.
    match key
    | (instanceof Inquire)      => @_handleInquire key, options
    | (is \Array) . (typeof!)   => @_handleArray key, options
    | (is \String) . (typeof!)  => @_handleString key, val, options
    | (is \Object) . (typeof!)  => @_handleObject key, options
    @_prune @inquiry
    this

  # Append whatever it is to us with a relation.
  _binary: !(key, val, options) ->
    # If it's empty, pretty much it can only be a string.
    if empty @inquiry
      # Construct our inquire.
      @inquiry =
        arity: arity options.rel
        rel: options.rel
        left: key
        right: val
      # If we're starting out with a unary operator, then wrap us in a unary.
      @_unary this, options if \1 is arity options.bool
    # There's something else here.
    # Put the old inquire as the left side and the new thing as the right.
    else
      # We need to do some special-ness for `not`.
      # If we're `not`-ing something and there's already a `not` child,
      # replace the `rel` with '&!' and the `bool` with ''.
      [rel, bool] = match options.bool, options.rel
      | \!, \!  => <[ &! '' ]>
      | _, _    => [options.bool, options.rel]
      if rel is options.bool
        @inquiry =
          arity: arity options.bool
          bool: options.bool
          left: @inquiry
          right: (Inquire!._analyze key, val,
            arity: arity options.bool
            bool: options.bool
            rel: options.rel).inquiry
      else
        @inquiry =
          arity: arity rel
          bool: rel
          left: @inquiry
          right: (Inquire!._analyze key, val,
            arity: arity bool
            bool: bool
            rel: options.rel).inquiry

  # Wrap the inquiry in parens, basically.
  _unary: !(val, options) ->
    @inquiry =
      arity: arity options.bool
      bool: options.bool
      value: val.inquiry

  _handleArray: !(array, options) ->
    # Create a new inquire
    inquire = Inquire!
    # Set the operator
    boolean = match options.bool
    | \;  => \or
    | _   => \and
    # Stuff the inquires from the arry into it.
    for item in array
      inquire[boolean] item, null, options
    # Now put that inquire into our inquire.
    @_handleInquire inquire, {options.bool, options.rel}

  _handleInquire: !(inquire, options) ->
    # We have our new inquire.
    # Put that into our inquire.
    if empty @inquiry
      # The only time we want a `bool` value is when it's negation.
      bool = if options.bool is \! then options.bool else ''
      @_unary inquire, {bool: bool}
    else
      # We have to make the rel into the `bool` because of `not`.
      @_binary inquire, null, {options.bool, rel: options.bool}

  _handleObject: !(object, options) ->
    # Create a new inquire.
    inquire = Inquire!
    # First let's check to see if we're trying to build a parsed query.
    if object._parsedQueryString?
      @_unary {inquiry: object._parsedQueryString}, options
      return
    # Set the relational operator
    rel = relation options.rel
    # Stuff the keys and values into it.
    for key, val of object
      inquire[rel] key, val, options
    # Now put that inquire into our inquire.
    @_handleInquire inquire, {options.bool, options.rel}

  # At this point, just dish off to `_binary`
  _handleString: !(key, val, options) -> @_binary key, val, options

  # Trim down the tree as much as possible.
  _prune: !->
    # There's a few different cases here.
    # A paren within a paren can go, e.g.: ((key=val)) => (key=val)
    # The top level paren can go, e.g.: (key=val) => key=val
    # probably more...
    if it.arity is \1 and it.value.arity is \1 and it.bool in <[ ! ]> ++ ''
      @inquiry = it.value
      @inquiry.bool = it.bool if it.bool
      @inquiry.rel = it.rel if it.rel
      @_prune @inquiry.value
    if it.arity is \2 and it.right.arity is \1 and it.bool is \&!
      it.right = it.right.value
      @inquiry = it
      @_prune @inquiry

  /*  Relational operators.
  */
  eq: (key, val)  -> @_analyze key, val, {rel: \=}
  neq: (key, val) -> @_analyze key, val, {rel: \!=}
  gt: (key, val)  -> @_analyze key, val, {rel: \>}
  gte: (key, val) -> @_analyze key, val, {rel: \>=}
  lt: (key, val)  -> @_analyze key, val, {rel: \<}
  lte: (key, val) -> @_analyze key, val, {rel: \<=}

  /*  Boolean predicates.
  */
  and: (key, val) -> @_analyze key, val, {bool: \&}
  or: (key, val)  -> @_analyze key, val, {bool: \;}
  not: -> @_analyze it, null, {bool: \!}

  /*  Make our Inquire actually look like a query string.
  */
  generate: -> "?#{@_gen @_unwrap @inquiry}"

  # Remove some parens.
  _unwrap: (I) -> if I.bool is '' then @_unwrap I.value else I

  # Recurse down our tree, and print out the good stuff.
  _gen: (I) ->
    if typeof! I in <[ Array Boolean Number String ]>
      encodeURIComponent I
    else if empty I
      ''
    else if I.arity is \1
      match I.bool
      | (is \empty) => ''
      | otherwise   => "#{I.bool}(#{@_gen @_unwrap I.value})"
    else if I.arity is \2
      match I.rel, I.bool
      | (?), _          => "#{@_gen I.left}#{I.rel}#{@_gen I.right}"
      | _, (is \&!)     => "#{@_gen I.left}#{I.bool}(#{@_gen I.right})"
      | _, (is \concat) => "(#{@_gen I.left})&(#{@_gen I.right})"
      | _, (?)          => "#{@_gen I.left}#{I.bool}#{@_gen I.right}"

  toString: -> @_gen @inquiry

  /*  Read in a query string, and return an inquire.
  */
  parse: ->
    parsed = parser.parse it
    @_analyze parsed, null, {bool: ''}

  /*  Fantasy-land

      Everything in here should be pure, and not mutate other things.
      This is the only place where you can guarantee anything.
  */

  /*  Semigroup

      1.  `a.concat(b).concat(c)` is equivalent to `a.concat(b.concat(c))`
          (associativity)

      `concat` method

      A value which has a Semigroup must provide a `concat` method. The
      `concat` method takes one argument:

        s.concat(b)

      1.  `b` must be a value of the same Semigroup

          1.  If `b` is not the same semigroup, behaviour of `concat` is
              unspecified.

      2.  `concat` must return a value of the same Semigroup.
  */
  concat: (I) ->
    # Take the entirety of our current inquire and clone it to and empty object.
    old-i = {} <<< @inquiry
    # Create a new inquire, then set the old attributes.
    new-i = @@!
    new-i.inquiry =
      arity: \2
      bool: \concat
      left: old-i
      right: I.inquiry
    # Return our new inquire.
    new-i

  /*  Monoid

      A value that implements the Monoid specification must also implement
      the Semigroup specficiation.

      1. `m.concat(m.empty())` is equivalent to `m` (right identity)
      2. `m.empty().concat(m)` is equivalent to `m` (left identity)

      `empty` method

      A value which has a Monoid must provide an `empty` method on itself or
      its `constructor` object. The `empty` method takes no arguments:

        m.empty()
        m.constructor.empty()

      1. `empty` must return a value of the same Monoid
  */
  empty: ->
    new-i = @@!
    new-i.inquiry =
      arity: \1
      bool: \empty
      value: ''
    new-i

/*  Static methods.
    We can do stuff like:
    LiveScript

    `Inquire.gt \a, 10` along with `Inquire!.gt \a, 10`.

    Javascript

    `Inquire.gt('a', 10)` along with `Inquire().gt('a', 10)`.
*/
Inquire.eq = (key, val) -> Inquire!.eq key, val
Inquire.neq = (key, val) -> Inquire!.neq key, val
Inquire.gt = (key, val) -> Inquire!.gt key, val
Inquire.gte = (key, val) -> Inquire!.gte key, val
Inquire.lt = (key, val) -> Inquire!.lt key, val
Inquire.lte = (key, val) -> Inquire!.lte key, val
Inquire.and = (key, val) -> Inquire!.and key, val
Inquire.or = (key, val) -> Inquire!.or key, val
Inquire.not = -> Inquire!.not it
Inquire.parse = -> Inquire!.parse it

/*  Exporting inquire.  */
if module?exports
  module.exports = Inquire
else
  @Inquire = Inquire
if typeof define is \function
  define \Inquire [] -> Inquire
