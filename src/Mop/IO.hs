module Mop.IO where

import Mop
import Effect.Exception
import qualified Control.Exception as Exc
import System.IO.Unsafe

{-# INLINE inlineUnsafePerformMIO #-}
inlineUnsafePerformMIO :: forall fs m a. Functor m => IO a -> PlanT fs m a
inlineUnsafePerformMIO = (return :: forall z. z -> PlanT fs m z) . unsafePerformIO

{-# NOINLINE unsafePerformMIO #-}
unsafePerformMIO :: forall fs m a. Functor m => IO a -> PlanT fs m a
unsafePerformMIO = (return :: forall z. z -> PlanT fs m z) . unsafePerformIO

class Monad m => MIO m where
  unsafeMIO :: IO a -> PlanT fs m a
  mio :: Has Throw fs m => IO a -> PlanT fs m a

instance MIO IO where
  {-# INLINE unsafeMIO #-}
  unsafeMIO = lift
  {-# INLINE mio #-}
  mio ioa = do
    ea <- lift $ Exc.try ioa
    case ea of
      Left e -> throw (e :: SomeException)
      Right r -> return r
