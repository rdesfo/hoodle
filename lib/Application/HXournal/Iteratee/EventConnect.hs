module Application.HXournal.Iteratee.EventConnect where

import Graphics.UI.Gtk hiding (get,set)
import Application.HXournal.Type.Event
import Application.HXournal.Type.XournalState
import Application.HXournal.Device
import Application.HXournal.Type.Coroutine

import qualified Control.Monad.State as St
import Control.Applicative
import Control.Monad.Trans

import Data.Label 
import Prelude hiding ((.), id)

connPenMove :: (WidgetClass w) => w -> Iteratee MyEvent XournalStateIO (ConnectId w) 
connPenMove c = do 
  callbk <- get callBack <$> lift St.get 
  dev <- get deviceList <$> lift St.get 
  liftIO (c `on` motionNotifyEvent $ tryEvent $ do 
             p <- getPointer dev
             liftIO (callbk (PenMove p)))

connPenUp :: (WidgetClass w) => w -> Iteratee MyEvent XournalStateIO (ConnectId w) 
connPenUp c = do 
  callbk <- get callBack <$> lift St.get 
  dev <- get deviceList <$> lift St.get 
  liftIO (c `on` buttonReleaseEvent $ tryEvent $ do 
             p <- getPointer dev
             liftIO (callbk (PenMove p)))
