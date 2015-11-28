{-# LANGUAGE DataKinds #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeFamilies #-}
module Ef.Core
    ( module Core
    , delta
    , delta'
    , deltaUpcast
    , deltaDebug
--    , run
    , (#)
    , Exception.Exception(..)
    , Exception.SomeException
    ) where

import Ef.Core.Type.Set as Core
import Ef.Core.Type.Nat as Core

import Ef.Core.Object as Core
import Ef.Core.Object.Attributes as Core

import Ef.Core.Pattern as Core
import Ef.Core.Pattern.Symbols as Core
import Ef.Core.Pattern.Exception as Core

import Ef.Core.Witness as Core

import qualified Control.Exception as Exception
import Data.Typeable (Typeable,typeOf)
import Debug.Trace
import Unsafe.Coerce



(#)
    :: ( Witnessing (Attrs is) (Symbol symbols)
       , Monad m
       )
    => m (Object is m)
    -> Pattern symbols m a
    -> m (Object is m)
(#) mobj p =
    do
      obj <- mobj
      (obj',_) <- delta obj p
      return obj'



delta'
    :: forall fs sf is m a.
       ( Witnessing (Attrs is) (Symbol sf)
       , As (Symbol fs) (Symbol sf)
       , Monad m
       )
    => Object is m
    -> Pattern fs m a
    -> m (Object is m,a)
delta' o =
    _delta o . rearrange



deltaUpcast
    :: forall small large is m a.
       ( Witnessing (Attrs is) (Symbol large)
       , Cast small large
       , Monad m
       )
    => Object is m
    -> Pattern small m a
    -> m (Object is m,a)
deltaUpcast o =
    _delta o . upcast



delta
    :: forall symbols is m a.
       ( Witnessing (Attrs is) (Symbol symbols)
       , Monad m
       )
    => Object is m
    -> Pattern symbols m a
    -> m (Object is m,a)
delta =
    _delta



{-# NOINLINE _delta #-}
_delta
    :: forall is symbols m a.
       ( Witnessing (Attrs is) (Symbol symbols)
       , Monad m
       )
    => Object is m
    -> Pattern symbols m a
    -> m (Object is m,a)
_delta =
    go
  where
    go is = go'
      where
        go' p =
            case p of

              Fail e ->
                  Exception.throw e

              Step syms k ->
                  let
                    ~(trans,b) =
                        witness (,) (deconstruct is) syms
                  in
                    do
                      is' <- trans is
                      go is' (k b)

              M mp ->
                  mp >>= go'

              Pure res ->
                  pure (is,res)



deltaDebug
    :: forall is symbols m a.
       ( Witnessing (Attrs is) (Symbol symbols)
       , Typeable symbols
       , Typeable is
       , Monad m
       )
    => Object is m
    -> Pattern symbols m a
    -> m ( Object is m
         , (Int,a)
         )
deltaDebug =
    _deltaDebug



{-# NOINLINE _deltaDebug #-}
_deltaDebug
    :: forall is symbols m a.
       ( Witnessing (Attrs is) (Symbol symbols)
       , Typeable symbols
       , Typeable is
       , Monad m
       )
    => Object is m
    -> Pattern symbols m a
    -> m ( Object is m
         , (Int,a)
         )
_deltaDebug =
    go 0
  where
    go n is = go'
      where
        go' p =
            case p of

                Fail e ->
                    Exception.throw e

                Step syms k ->
                  let
                    ~(trans,b) =
                        witness (,) (deconstruct is) syms

                  in
                    do
                      is' <- trans is
                      let
                        n' =
                            n + 1

                        unitalSymbols =
                            unsafeCoerce syms :: Symbol symbols ()

                        ty =
                            typeOf unitalSymbols

                      trace (show ty) $ n' `seq` go n' is' (k b)

                M m ->
                    m >>= go'

                Pure r ->
                    let
                      result =
                          (n,r)

                    in
                      pure (is,result)
