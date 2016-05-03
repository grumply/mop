{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE ExistentialQuantification #-}
{-# LANGUAGE ConstraintKinds #-}
{-# LANGUAGE Safe #-}
module Ef.Object
    ( Trait
    , Subclass
    , Has(..)
    , Use
    , stretch
    , Traits(..)
    , Object(..)
    , (*:*)
    , view
    , view2
    , view3
    , view4
    , view5
    , view6
    , view7
    , view8
    , (.=)
    ) where

import Ef.Type.Set
import Ef.Traits

import Ef.Type.Nat
import Control.DeepSeq

type Trait trait traits super =
    trait (Object traits super -> super (Object traits super))

type Use trait traits super =
    (Has' trait traits (Offset trait traits), Monad super)
    => trait (Object traits super -> super (Object traits super))

type family Subclass (traits :: [* -> *]) traits' where

    Subclass (trait ': '[]) traits' =
        (Has' trait traits' (Offset trait traits'))

    Subclass (trait ': traits) traits' =
        (Has' trait traits' (Offset trait traits'),traits `Subclass` traits')



type family Superclass traits traits' where

    Superclass traits traits' =
        traits' `Subclass` traits



newtype Object traits super =
      Object
          {
            deconstruct
                :: Traits traits (Object traits super -> super (Object traits super))
          }

instance (NFData (Traits traits (Object traits super -> super (Object traits super)))) => NFData (Object traits super) where
    rnf (Object traits) = rnf traits

instance (Eq (Traits traits (Object traits super -> super (Object traits super))))
        => Eq (Object traits super)
    where

        (Object o1) == (Object o2) =
            o1 == o2


instance (Ord (Traits traits (Object traits super -> super (Object traits super))))
        => Ord (Object traits super)
     where

         (Object o1) <= (Object o2) =
             o1 <= o2


-- -- Orphans
-- instance Binary TyCon
-- instance Binary TypeRep
-- deriving instance Generic TyCon
-- deriving instance Generic TypeRep



-- instance ( Typeable (Object traits super)
--          , Binary (Traits traits (Object traits super -> super (Object traits super)))
--          )
--     => Binary (Object traits super)
--   where

--     get =
--         do
--           typeRep <- get
--           if typeRep == typeOf (undefined :: Object traits super) then
--               Object <$> get
--           else
--               mzero



--     put o@(Object as) =
--         do
--           put (typeOf o)
--           put as



instance Show (Traits traits (Object traits super -> super (Object traits super)))
         => Show (Object traits super)
    where

        show (Object traits) =
            "{ " ++ show traits ++ " }"



infixr 6 *:*

(*:*)
    :: Denies trait traits
    => trait a
    -> Traits traits a
    -> Traits (trait ': traits) a

(*:*) = Trait



view
    :: Has trait traits
    => Object traits super
    -> Trait trait traits super

view =
    pull . deconstruct



view2
    :: (traits `Superclass` '[trait1,trait2])
    => Object traits super
    -> ( Trait trait1 traits super
       , Trait trait2 traits super
       )
view2 obj =
    (view obj,view obj)



view3
    :: (traits `Superclass` '[trait1,trait2,trait3])
    => Object traits super
    -> ( Trait trait1 traits super
       , Trait trait2 traits super
       , Trait trait3 traits super
       )
view3 obj =
    (view obj,view obj,view obj)




view4
    :: (traits `Superclass` '[trait1,trait2,trait3,trait4])
    => Object traits super
    -> ( Trait trait1 traits super
       , Trait trait2 traits super
       , Trait trait3 traits super
       , Trait trait4 traits super
       )
view4 obj =
    (view obj,view obj,view obj,view obj)




view5
    :: ( traits `Superclass`
            '[trait1,trait2,trait3,trait4
             ,trait5]
       )
    => Object traits super
    -> ( Trait trait1 traits super
       , Trait trait2 traits super
       , Trait trait3 traits super
       , Trait trait4 traits super
       , Trait trait5 traits super
       )
view5 obj =
    (view obj,view obj,view obj,view obj,view obj)



view6
    :: ( traits `Superclass`
            '[trait1,trait2,trait3,trait4
             ,trait5,trait6]
       )
    => Object traits super
    -> ( Trait trait1 traits super
       , Trait trait2 traits super
       , Trait trait3 traits super
       , Trait trait4 traits super
       , Trait trait5 traits super
       , Trait trait6 traits super
       )
view6 obj =
    (view obj,view obj,view obj,view obj,view obj,view obj)



view7
    :: ( traits `Superclass`
            '[trait1,trait2,trait3,trait4
             ,trait5,trait6,trait7]
       )
    => Object traits super
    -> ( Trait trait1 traits super
       , Trait trait2 traits super
       , Trait trait3 traits super
       , Trait trait4 traits super
       , Trait trait5 traits super
       , Trait trait6 traits super
       , Trait trait7 traits super
       )
view7 obj =
    (view obj,view obj,view obj,view obj,view obj,view obj,view obj)



view8
    :: ( traits `Superclass`
            '[trait1,trait2,trait3,trait4
             ,trait5,trait6,trait7,trait8]
       )
    => Object traits super
    -> ( Trait trait1 traits super
       , Trait trait2 traits super
       , Trait trait3 traits super
       , Trait trait4 traits super
       , Trait trait5 traits super
       , Trait trait6 traits super
       , Trait trait7 traits super
       , Trait trait8 traits super
       )
view8 obj =
    (view obj,view obj,view obj,view obj,view obj,view obj,view obj,view obj)



infixl 5 .=

(.=)
    :: ( Has trait traits
       , Monad super
       )
    => Object traits super
    -> Trait trait traits super
    -> Object traits super

is .= x =
    let
        deconstructed =
            deconstruct is

    in
      Object (push x deconstructed)
