'use strict'

class Inquire

  inquiry: null

  # Bound constructor allows us to call `Inquire()` rather than `new Inquire()`.
  (key, val) ~>
    @_relHelper key, val, '='

  _relHelper: (key, val, op) ->
    # Check what we got here.
    # If it's an Inquire, just wrap it in parens.
    # For arrays, conjoin everything, and wrap it in parens.
    # For strings, just make it equal.
    # For objects, conjoin each key/val pair, and wrap it in parens.
    # Otherwise, just make the inquiry an empty string.
    @inquiry = match key
    | (instanceof Inquire)        => "(#{key})"
    | (('Array' ==) . (typeof!))  => "(#{key.join '&'})"
    | (('String' ==) . (typeof!)) => "#{key}#{op}#{val}"
    | (('Object' ==) . (typeof!)) => "(#{[k+op+v for k, v of key].join '&'})"
    | otherwise                   => ''
    this

  # Relational operators.
  eq: (key, val) -> @_relHelper key, val, '='
  neq: (key, val) -> @_relHelper key, val, '!='
  gt: (key, val) -> @_relHelper key, val, '>'
  gte: (key, val) -> @_relHelper key, val, '>='
  lt: (key, val) -> @_relHelper key, val, '<'
  lte: (key, val) -> @_relHelper key, val, '<='

  # Wrapper for and/or.
  _boolHelper: (key, val, pred) ->
    # If we got an Inquire, just wrap it in parens and concat it with the pred.
    # Otherwise, assume we got a key/val pair, and concat it with the pred.
    @inquiry += match key
    | (instanceof Inquire)        => "#{pred}(#{key})"
    | (('Array' ==) . (typeof!))  => "#{pred}(#{key.join pred})"
    | (('String' ==) . (typeof!)) => "#{pred}#{key}=#{val}"
    | (('Object' ==) . (typeof!)) => "#{pred}(#{[k+'='+v for k, v of key].join pred})"
    | otherwise                   => ''
    this

  # Boolean predicates.
  and: (key, val) -> @_boolHelper key, val, '&'
  or: (key, val) -> @_boolHelper key, val, ';'

  # Negation.
  not: (I) ->
    # If we got an Inquire (which only makes sense), wrap it in parens.
    if I instanceof Inquire
      @inquiry = "!(#{I.inquiry})"
    # TODO: Should probably handle other cases here.
    #       Should be able to take all the same inputs as the others,
    #       and just wrap them in parens.
    this

  # Make our Inquire actually look like a query string.
  generate: -> "?#{@inquiry}"

  toString: -> @inquiry

# Static methods.
# We can do stuff like `Inquire.gt \a, 10` along with `Inquire!.gt \a, 10`.
Inquire.eq = (key, val) -> Inquire!.eq key, val
Inquire.neq = (key, val) -> Inquire!.neq key, val
Inquire.gt = (key, val) -> Inquire!.gt key, val
Inquire.gte = (key, val) -> Inquire!.gte key, val
Inquire.lt = (key, val) -> Inquire!.lt key, val
Inquire.lte = (key, val) -> Inquire!.lte key, val

module.exports = Inquire
