module Inquire.Combinators where

  import Prelude
  import Inquire
  import Data.Array ((:), zipWith)
  import Data.Foldable (Foldable, bifoldr)
  import Data.Functor (BiFunctor)
  import Data.Maybe
  import Data.Monoid
  import Data.Tuple

  -- Utilities for working with Inquire.
  toObj :: forall k v. Inquire k v -> {keys :: [k], vals :: [v]}
  toObj i =
    let updateVals = (\v o -> o {vals = v : o.vals}) in
    let updateKeys = (\k o -> o {keys = k : o.keys}) in
    bifoldr updateKeys updateVals {keys: [], vals: []} i

  keys :: forall k v. Inquire k v -> [k]
  keys i = (toObj i).keys

  vals :: forall k v. Inquire k v -> [v]
  vals i = (toObj i).vals

  toTuple :: forall k v. Inquire k v -> [Tuple k v]
  toTuple i = zip (keys i) (vals i)

  -- The ideal type would be
  -- toArrayPair :: forall k v. Inquire k v -> [[k, v]]
  toArrayPair i = zipWith (\x y -> [x,y]) (keys i) (vals i)

  toArrayObj :: forall k v. Inquire k v -> [{key :: k, val :: v}]
  toArrayObj i = zipWith (\x y -> {key: x, val: y}) (keys i) (vals i)

  -- The ideal type would be
  -- fromArrayPair :: forall k v. [[k, v]] -> Inquire k v
  fromArrayPair []         = EmptyAnd
  fromArrayPair ([x,y]:zs) = (fromArrayPair zs) `and` (x `eq` y)

  fromArrayObj :: forall k v. [{key :: k, val :: v}] -> Inquire k v
  fromArrayObj []                        = EmptyAnd
  fromArrayObj ({ key = x, val = y }:zs) = (fromArrayObj zs) `and` (x `eq` y)

  -- This should be implemented with a foldr or some such,
  -- but the kind wont work out.
  filterByVal :: forall k v. (v -> Boolean) -> Inquire k v -> Inquire k v
  filterByVal p (Pred k r v) = if p v then Pred k r v else mempty
  filterByVal p (Junc l o r) = Junc (filterByVal p l) o (filterByVal p r)
  filterByVal p (Wrap o i)   = Wrap o (filterByVal p i)
  filterByVal p i            = i

  filterByKey :: forall k v. (k -> Boolean) -> Inquire k v -> Inquire k v
  filterByKey p (Pred k r v) = if p k then Pred k r v else mempty
  filterByKey p (Junc l o r) = Junc (filterByKey p l) o (filterByKey p r)
  filterByKey p (Wrap o i)   = Wrap o (filterByKey p i)
  filterByKey p i            = i

  -- This is a right based find.
  findByVal :: forall k v. (Eq v) => v -> Inquire k v -> Maybe (Inquire k v)
  findByVal v (Pred k r v') | v == v' = Just (Pred k r v)
  findByVal v (Pred k r v')           = Nothing
  findByVal v (Junc l _ r)            = maybe (findByVal v l) Just (findByVal v r)
  findByVal v (Wrap _ i)              = findByVal v i
  findByVal _ _                       = Nothing

  findByKey :: forall k v. (Eq k) => k -> Inquire k v -> Maybe (Inquire k v)
  findByKey k (Pred k' r v) | k == k' = Just (Pred k r v)
  findByKey k (Pred k' r v)           = Nothing
  findByKey k (Junc l _ r)            = maybe (findByKey k l) Just (findByKey k r)
  findByKey k (Wrap _ i)              = findByKey k i
  findByKey _ _                       = Nothing

  remove' :: forall k v. (Eq k, Eq v) => (Inquire k v -> Inquire k v -> Boolean) -> Inquire k v -> Inquire k v -> Inquire k v
  remove' p i (Junc l o r) =
    let r' = remove' p i r in
    if p r r' then Junc (remove' p i l) o r else Junc l o r'
  remove' p i (Wrap o i')  = Wrap o (remove' p i i')
  remove' p i i' | i == i' = EmptyAnd
  remove' p i i'           = i'

  remove :: forall k v. (Eq k, Eq v) => Inquire k v -> Inquire k v -> Inquire k v
  remove = remove' (==)

  removeAll :: forall k v. (Eq k, Eq v) => Inquire k v -> Inquire k v -> Inquire k v
  removeAll = remove' (\x y -> true)

  replaceValByKey :: forall k v. (Eq k) => v -> k -> Inquire k v -> Inquire k v
  replaceValByKey v k (Pred k' r _) | k == k' = Pred k r v
  replaceValByKey v k (Junc l o r)            = Junc (replaceValByKey v k l) o (replaceValByKey v k r)
  replaceValByKey v k (Wrap o i)              = Wrap o (replaceValByKey v k i)
  replaceValByKey _ _ i                       = i

  replaceValByVal :: forall k v. (Eq v) => v -> v -> Inquire k v -> Inquire k v
  replaceValByVal v v' (Pred k r v'') | v' == v'' = Pred k r v
  replaceValByVal v v' (Junc l o r)               = Junc (replaceValByVal v v' l) o (replaceValByVal v v' r)
  replaceValByVal v v' (Wrap o i)                 = Wrap o (replaceValByVal v v' i)
  replaceValByVal _ _  i                          = i

  foreign import bimap
    "function bimap(f) {\
    \ return function(g) {\
    \    return function(x) {\
    \      return _ps.Data_Functor['<$$>'](_ps.Inquire.biFunctorInquire({}))(f)(g)(x);\
    \    }\
    \  }\
    \}" :: forall a b c d f. (BiFunctor f) => (a -> c) -> (b -> d) -> f a b -> f c d

  foreign import map
    "function map(f) {\
    \  return function(x) {\
    \    return _ps.Prelude['<$>'](_ps.Inquire.functorInquire({}))(f)(x);\
    \  }\
    \}" :: forall a b f. (Functor f) => (a -> b) -> f a -> f b

  foreign import unsafeFindByKey
    "function unsafeFindByKey(v) {\
    \  return function(i) {\
    \    /* We use String's eq typeclass because it uses `unsafeRefEq`*/\
    \    return findByKey(_ps.Prelude.eqString({}))(v)(i);\
    \  }\
    \}" :: forall k v. v -> Inquire k v -> Maybe (Inquire k v)

  foreign import unsafeFindByVal
    "function unsafeFindByVal(v) {\
    \  return function(i) {\
    \    /* We use String's eq typeclass because it uses `unsafeRefEq`*/\
    \    return findByVal(_ps.Prelude.eqString({}))(v)(i);\
    \  }\
    \}" :: forall k v. v -> Inquire k v -> Maybe (Inquire k v)

  foreign import unsafeRemove
    "function unsafeRemove(i1) {\
    \  return function(i2) {\
    \    /* We use String's eq typeclass because it uses `unsafeRefEq`*/\
    \    return remove(_ps.Prelude.eqString({}))(_ps.Prelude.eqString({}))(i1)(i2);\
    \  }\
    \}" :: forall k v. v -> Inquire k v -> Inquire k v -> Inquire k v

  foreign import unsafeRemoveAll
    "function unsafeRemoveAll(i1) {\
    \  return function(i2) {\
    \    /* We use String's eq typeclass because it uses `unsafeRefEq`*/\
    \    return removeAll(_ps.Prelude.eqString({}))(_ps.Prelude.eqString({}))(i1)(i2);\
    \  }\
    \}" :: forall k v. v -> Inquire k v -> Inquire k v -> Inquire k v

  foreign import unsafeReplaceValByKey
    "function unsafeReplaceValByKey(v) {\
    \  return function(k) {\
    \    return function(i) {\
    \      /* We use String's eq typeclass because it uses `unsafeRefEq`*/\
    \      return replaceValByKey(_ps.Prelude.eqString({}))(v)(k)(i);\
    \    }\
    \  }\
    \}" :: forall k v. v -> k -> Inquire k v -> Inquire k v

  foreign import unsafeReplaceValByVal
    "function unsafeReplaceValByVal(v1) {\
    \  return function(v2) {\
    \    return function(i) {\
    \      /* We use String's eq typeclass because it uses `unsafeRefEq`*/\
    \      return replaceValByVal(_ps.Prelude.eqString({}))(v1)(v2)(i);\
    \    }\
    \  }\
    \}" :: forall k v. v -> v -> Inquire k v -> Inquire k v
