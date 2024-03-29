{-# LANGUAGE OverloadedStrings #-}

{-|
    A Snap adapter to the HTML5 Server-Sent Events API.  Push-mode and
    pull-mode interfaces are both available.
-}
module EventStream (
    ServerEvent(..),
    eventToBuilder
    ) where

import Blaze.ByteString.Builder
import Blaze.ByteString.Builder.Char8
import Control.Monad.Trans
import Control.Concurrent
import Data.Monoid
import Data.Enumerator hiding (map)
import Data.Enumerator.List (generateM)

{-|
    Type representing a communication over an event stream.  This can be an
    actual event, a comment, a modification to the retry timer, or a special
    "close" event indicating the server should close the connection.
-}
data ServerEvent
    = ServerEvent {
        eventName :: Maybe Builder,
        eventId   :: Maybe Builder,
        eventData :: [Builder]
        }
    | CommentEvent {
        eventComment :: Builder
        }
    | RetryEvent {
        eventRetry :: Int
        }
    | CloseEvent


{-|
    Newline as a Builder.
-}
nl = fromChar '\n'


{-|
    Field names as Builder
-}
nameField = fromString "event:"
idField = fromString "id:"
dataField = fromString "data:"
retryField = fromString "retry:"
commentField = fromChar ':'


{-|
    Wraps the text as a labeled field of an event stream.
-}
field l b = l `mappend` b `mappend` nl


{-|
    Appends a buffer flush to the end of a Builder.
-}
flushAfter b = b `mappend` flush


{-|
    Converts a 'ServerEvent' to its wire representation as specified by the
    @text/event-stream@ content type.
-}
eventToBuilder :: ServerEvent -> Maybe Builder
eventToBuilder (CommentEvent txt) = Just $ flushAfter $ field commentField txt
eventToBuilder (RetryEvent   n)   = Just $ flushAfter $ field retryField (fromShow n)
eventToBuilder (CloseEvent)       = Nothing
eventToBuilder (ServerEvent n i d)= Just $ flushAfter $
    (name n $ evid i $ mconcat (map (field dataField) d)) `mappend` nl
  where
    name Nothing  = id
    name (Just n) = mappend (field nameField n)
    evid Nothing  = id
    evid (Just i) = mappend (field idField   i)
