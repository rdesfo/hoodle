{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

-----------------------------------------------------------------------------
-- |
-- Module      : Graphics.Hoodle.Render.PDFBackground 
-- Copyright   : (c) 2011-2014 Ian-Woo Kim
--
-- License     : BSD3
-- Maintainer  : Ian-Woo Kim <ianwookim@gmail.com>
-- Stability   : experimental
-- Portability : GHC
--
-----------------------------------------------------------------------------

module Graphics.Hoodle.Render.Background where

import           Control.Monad.State hiding (mapM_)
import           Data.ByteString hiding (putStrLn,filter)
import           Data.Foldable (mapM_)
import qualified Data.Map as M
import           Data.ByteString.Base64 
import qualified Data.ByteString.Char8 as C
import           Data.Monoid
import           Data.UUID.V4 (nextRandom)
import qualified Graphics.Rendering.Cairo as Cairo
import qualified Graphics.UI.Gtk.Poppler.Document as Poppler
import qualified Graphics.UI.Gtk.Poppler.Page as PopplerPage
import           System.Directory
import           System.FilePath ((</>),(<.>))
-- from hoodle-platform
import           Data.Hoodle.BBox
import           Data.Hoodle.Predefined 
import           Data.Hoodle.Simple
--
import           Graphics.Hoodle.Render.Type.Background
-- 
import Prelude hiding (mapM_)

-- |
popplerGetDocFromFile :: ByteString -> IO (Maybe Poppler.Document)
popplerGetDocFromFile fp = 
  Poppler.documentNewFromFile 
    (C.unpack ("file://localhost" `mappend` fp)) Nothing 

-- |
getByteStringIfEmbeddedPDF :: ByteString -> Maybe ByteString 
getByteStringIfEmbeddedPDF bstr = do 
    guard (C.length bstr > 30)
    let (header,dat) = C.splitAt 30 bstr 
    guard (header == "data:application/x-pdf;base64,") 
    either (const Nothing) return (decode dat)

-- | 
popplerGetDocFromDataURI :: ByteString -> IO (Maybe Poppler.Document) 
popplerGetDocFromDataURI dat = do 
  let mdecoded = getByteStringIfEmbeddedPDF dat 
  case mdecoded of 
    Nothing -> return Nothing 
    Just decoded -> do 
      uuidstr <- liftM show nextRandom
      tmpdir <- getTemporaryDirectory 
      let tmpfile = tmpdir </> uuidstr <.> "pdf" 
      C.writeFile tmpfile decoded 
      mdoc <- popplerGetDocFromFile (C.pack tmpfile)
      removeFile tmpfile 
      return mdoc 

-- |
popplerGetPageFromDoc :: Poppler.Document 
                      -> Int -- ^ page number 
                      -> IO (Maybe Poppler.Page, Maybe Cairo.Surface)
popplerGetPageFromDoc doc pn = do   
  n <- Poppler.documentGetNPages doc 
  if pn > n 
    then return (Nothing, Nothing)
    else do 
      pg <- Poppler.documentGetPage doc (pn-1) 
      (w,h) <- PopplerPage.pageGetSize pg
      sfc <- Cairo.createImageSurface Cairo.FormatARGB32 (floor w) (floor h)
      Cairo.renderWith sfc $ do   
        Cairo.setSourceRGBA 1 1 1 1
        Cairo.rectangle 0 0 w h 
        Cairo.fill
        PopplerPage.pageRender pg
      return (Just pg, Just sfc)

-- | draw ruling all 
drawRuling :: Double -> Double -> ByteString -> Cairo.Render () 
drawRuling w h style = do
  let drawHorizRules = do 
      let (r,g,b,a) = predefined_RULING_COLOR         
      Cairo.setSourceRGBA r g b a 
      Cairo.setLineWidth predefined_RULING_THICKNESS
      let drawonerule y = do 
            Cairo.moveTo 0 y 
            Cairo.lineTo w y
            Cairo.stroke  
      mapM_ drawonerule [ predefined_RULING_TOPMARGIN 
                        , predefined_RULING_TOPMARGIN+predefined_RULING_SPACING
                        .. 
                        h-1 ]
  case style of 
    "plain" -> return () 
    "lined" -> do 
      drawHorizRules
      let (r2,g2,b2,a2) = predefined_RULING_MARGIN_COLOR
      Cairo.setSourceRGBA r2 g2 b2 a2 
      Cairo.setLineWidth predefined_RULING_THICKNESS
      Cairo.moveTo predefined_RULING_LEFTMARGIN 0 
      Cairo.lineTo predefined_RULING_LEFTMARGIN h
      Cairo.stroke
    "ruled" -> drawHorizRules 
    "graph" -> do 
      let (r3,g3,b3,a3) = predefined_RULING_COLOR 
      Cairo.setSourceRGBA r3 g3 b3 a3 
      Cairo.setLineWidth predefined_RULING_THICKNESS
      let drawonegraphvert x = do 
            Cairo.moveTo x 0 
            Cairo.lineTo x h
            Cairo.stroke  
      let drawonegraphhoriz y = do 
            Cairo.moveTo 0 y
            Cairo.lineTo w y
            Cairo.stroke
      mapM_ drawonegraphvert  [0,predefined_RULING_GRAPHSPACING..w-1] 
      mapM_ drawonegraphhoriz [0,predefined_RULING_GRAPHSPACING..h-1]
    _ -> return ()     



-- | draw ruling  in bbox 
drawRuling_InBBox :: BBox -> Double -> Double -> ByteString -> Cairo.Render () 
drawRuling_InBBox (BBox (x1,y1) (x2,y2)) w h style = do
  let drawonerule y = do 
        Cairo.moveTo x1 y 
        Cairo.lineTo x2 y
        Cairo.stroke  
  let drawonegraphvert x = do 
        Cairo.moveTo x y1 
        Cairo.lineTo x y2
        Cairo.stroke  
  let drawonegraphhoriz y = do 
        Cairo.moveTo x1 y
        Cairo.lineTo x2 y
        Cairo.stroke
      fullRuleYs = [ predefined_RULING_TOPMARGIN 
                   , predefined_RULING_TOPMARGIN+predefined_RULING_SPACING
                   .. 
                   h-1 ]
      ruleYs = filter (\y-> (y <= y2) && (y >= y1)) fullRuleYs
      fullGraphXs = [0,predefined_RULING_GRAPHSPACING..w-1]          
      fullGraphYs = [0,predefined_RULING_GRAPHSPACING..h-1]
      graphXs = filter (\x->(x<=x2)&&(x>=x1)) fullGraphXs
      graphYs = filter (\y->(y<=y2)&&(y>=y1)) fullGraphYs 
  let drawHorizRules = do 
      let (r,g,b,a) = predefined_RULING_COLOR         
      Cairo.setSourceRGBA r g b a 
      Cairo.setLineWidth predefined_RULING_THICKNESS
      mapM_ drawonerule ruleYs
  case style of 
    "plain" -> return () 
    "lined" -> do 
      drawHorizRules
      let (r2,g2,b2,a2) = predefined_RULING_MARGIN_COLOR
      Cairo.setSourceRGBA r2 g2 b2 a2 
      Cairo.setLineWidth predefined_RULING_THICKNESS
      Cairo.moveTo predefined_RULING_LEFTMARGIN 0 
      Cairo.lineTo predefined_RULING_LEFTMARGIN h
      Cairo.stroke
    "ruled" -> drawHorizRules 
    "graph" -> do 
      let (r3,g3,b3,a3) = predefined_RULING_COLOR 
      Cairo.setSourceRGBA r3 g3 b3 a3 
      Cairo.setLineWidth predefined_RULING_THICKNESS
      mapM_ drawonegraphvert  graphXs 
      mapM_ drawonegraphhoriz graphYs
    _ -> return ()     


-- | render background without any constraint 
renderBkg :: (Background,Dimension) -> Cairo.Render () 
renderBkg (Background _typ col sty,Dim w h) = do 
    let c = M.lookup col predefined_bkgcolor  
    case c of 
      Just (r,g,b,_a) -> Cairo.setSourceRGB r g b 
      Nothing        -> Cairo.setSourceRGB 1 1 1 
    Cairo.rectangle 0 0 w h 
    Cairo.fill
    drawRuling w h sty
renderBkg (BackgroundPdf _ _ _ _,Dim w h) = do 
    Cairo.setSourceRGBA 1 1 1 1
    Cairo.rectangle 0 0 w h 
    Cairo.fill
renderBkg (BackgroundEmbedPdf _ _,Dim w h) = do 
    Cairo.setSourceRGBA 1 1 1 1
    Cairo.rectangle 0 0 w h 
    Cairo.fill



-- | this has some bugs. need to fix 
cnstrctRBkg_StateT :: Dimension -> Background 
                   -> StateT (Maybe Context) IO RBackground
cnstrctRBkg_StateT dim@(Dim w h) bkg = do  
  case bkg of 
    Background _t c s -> do 
      sfc <- liftIO $ Cairo.createImageSurface 
                        Cairo.FormatARGB32 (floor w) (floor h)
      Cairo.renderWith sfc $ renderBkg (bkg,dim) 
      return (RBkgSmpl c s (Just sfc))
    BackgroundPdf _t md mf pn -> do 
      case (md,mf) of 
        (Just d, Just f) -> do 
           mdoc <- liftIO $ popplerGetDocFromFile f
           put $ Just (Context d f mdoc Nothing)
           case mdoc of 
             Just doc -> do  
               (mpg,msfc) <- liftIO $ popplerGetPageFromDoc doc pn 
               return (RBkgPDF md f pn mpg msfc)
             Nothing -> error "error1 in cnstrctRBkg_StateT"
        _ -> do 
          mctxt <- get
          case mctxt of  
            Just (Context oldd oldf olddoc _) -> do 
              (mpage,msfc) <- case olddoc of 
                Just doc -> do 
                  liftIO $ popplerGetPageFromDoc doc pn
                Nothing -> error "error2 in cnstrctRBkg_StateT" 
              maybe (liftIO $ putStrLn ( "pn = " ++ show pn )) (const (return ())) mpage 
              return (RBkgPDF (Just oldd) oldf pn mpage msfc)
            Nothing -> error "error3 in cnstrctRBkg_StateT" 
    BackgroundEmbedPdf _ pn -> do 
      mctxt <- get
      case mctxt of  
        Just (Context _ _ _ mdoc) -> do 
          (mpage,msfc) <- case mdoc of 
            Just doc -> do 
              liftIO $ popplerGetPageFromDoc doc pn
            Nothing -> error "error4 in cnstrctRBkg_StateT" 
          return (RBkgEmbedPDF pn mpage msfc)
        Nothing -> error "error5 in cnstrctRBkg_StateT" 

