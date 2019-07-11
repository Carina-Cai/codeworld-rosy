{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE PackageImports #-}

{-
  Copyright 2019 The CodeWorld Authors. All rights reserved.

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

      http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
-}
module Internal.CodeWorld
    ( Program
    , drawingOf
    , animationOf
    , activityOf
    , debugActivityOf
    , groupActivityOf
    , simulationOf
    , debugSimulationOf
    , interactionOf
    , debugInteractionOf
    , collaborationOf
    , traced
    ) where

import qualified "codeworld-api" CodeWorld as CW
import Control.Exception
import Data.Text (Text)
import qualified Data.Text as T
import ErrorSanitizer
import Internal.Event
import Internal.Num (Number, fromDouble, fromInt, toDouble, toInt)
import Internal.Picture
import Internal.Prelude (randomsFrom)
import qualified Internal.Text as CWT
import "base" Prelude
import System.IO
import System.Random

data LiteralException = LiteralException Text
instance Exception LiteralException

instance Show LiteralException where
    show (LiteralException msg) = T.unpack (rewriteErrors msg)

traced :: (a, CWT.Text) -> a
traced (x, msg) = CW.trace (CWT.fromCWText msg) x

type Program = IO ()

drawingOf :: Picture -> Program
drawingOf pic = CW.drawingOf (toCWPic pic) `catch` reportError

animationOf :: (Number -> Picture) -> Program
animationOf f = CW.animationOf (toCWPic . f . fromDouble) `catch` reportError

activityOf ::
       ( [Number] -> world
       , (world, Event) -> world
       , world -> Picture)
    -> Program
activityOf (initial, event, draw) = interactionOf (initial, fst, event, draw)

debugActivityOf ::
       ( [Number] -> world
       , (world, Event) -> world
       , world -> Picture)
    -> Program
debugActivityOf (initial, event, draw) =
    debugInteractionOf (initial, fst, event, draw)

groupActivityOf ::
       ( Number
       , [Number] -> state
       , (state, Event, Number) -> state
       , (state, Number) -> Picture)
    -> Program
groupActivityOf (players, initial, event, picture) =
    collaborationOf (players, initial, fst, event, picture)

simulationOf ::
       ([Number] -> world, (world, Number) -> world, world -> Picture)
    -> Program
simulationOf (initial, step, draw) =
    do rs <- chooseRandoms
       CW.simulationOf
           (initial rs)
           (\dt w -> step (w, fromDouble dt))
           (toCWPic . draw)
       `catch` reportError

{-# WARNING simulationOf ["Please use activityOf instead of simulationOf.",
                          "simulationOf may be removed July 2020."] #-}

debugSimulationOf ::
       ([Number] -> world, (world, Number) -> world, world -> Picture)
    -> Program
debugSimulationOf (initial, step, draw) =
    do rs <- chooseRandoms
       CW.debugSimulationOf
           (initial rs)
           (\dt w -> step (w, fromDouble dt))
           (toCWPic . draw)
       `catch` reportError

{-# WARNING debugSimulationOf ["Please use debugActivityOf instead of debugSimulationOf.",
                               "debugSimulationOf may be removed July 2020."] #-}

interactionOf ::
       ( [Number] -> world
       , (world, Number) -> world
       , (world, Event) -> world
       , world -> Picture)
    -> Program
interactionOf (initial, step, event, draw) =
    do rs <- chooseRandoms
       CW.interactionOf
           (initial rs)
           (\dt w -> step (w, fromDouble dt))
           (\ev w -> event (w, fromCWEvent ev))
           (toCWPic . draw)
       `catch` reportError

{-# WARNING interactionOf ["Please use activityOf instead of interactionOf.",
                           "interactionOf may be removed July 2020."] #-}

debugInteractionOf ::
       ( [Number] -> world
       , (world, Number) -> world
       , (world, Event) -> world
       , world -> Picture)
    -> Program
debugInteractionOf (initial, step, event, draw) =
    do rs <- chooseRandoms
       CW.debugInteractionOf
           (initial rs)
           (\dt w -> step (w, fromDouble dt))
           (\ev w -> event (w, fromCWEvent ev))
           (toCWPic . draw)
       `catch` reportError

{-# WARNING debugInteractionOf ["Please use debugActivityOf instead of debugInteractionOf.",
                                "debugInteractionOf may be removed July 2020."] #-}

collaborationOf ::
       ( Number
       , [Number] -> state
       , (state, Number) -> state
       , (state, Event, Number) -> state
       , (state, Number) -> Picture)
    -> Program
collaborationOf (players, initial, step, event, picture)
    -- This is safe ONLY because codeworld-base does not export the
    -- IO combinators that allow for choosing divergent clients.
 =
    CW.unsafeCollaborationOf
        (toInt players)
        (initial . randomsFrom)
        (\dt state -> step (state, fromDouble dt))
        (\player ev state -> event (state, fromCWEvent ev, fromInt player + 1))
        (\player state -> toCWPic (picture (state, fromInt player + 1))) `catch`
    reportError

{-# WARNING collaborationOf ["Please use groupActivityOf instead of collaborationOf.",
                             "collaborationOf may be removed July 2020."] #-}

chooseRandoms :: IO [Number]
chooseRandoms = do
    g <- newStdGen
    return (map fromDouble (randomRs (0, 1) g))

reportError :: SomeException -> IO ()
reportError ex = throwIO (LiteralException (T.pack (show ex)))
