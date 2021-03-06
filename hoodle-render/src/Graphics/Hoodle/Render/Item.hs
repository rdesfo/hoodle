{-# LANGUAGE TypeFamilies, TypeOperators, MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}

-----------------------------------------------------------------------------
-- |
-- Module      : Graphics.Hoodle.Render.Item 
-- Copyright   : (c) 2011-2014 Ian-Woo Kim
--
-- License     : BSD3
-- Maintainer  : Ian-Woo Kim <ianwookim@gmail.com>
-- Stability   : experimental
-- Portability : GHC
--
-- Rendering RItem 
-- 
-----------------------------------------------------------------------------

module Graphics.Hoodle.Render.Item where

import           Control.Applicative
import           Control.Monad 
import           Control.Monad.Identity 
import qualified Data.ByteString as B
import qualified Data.ByteString.Char8 as C8
-- import qualified Data.ByteString.Lazy as LB
import           Data.ByteString.Base64 
import           Graphics.GD.ByteString
import qualified Graphics.Rendering.Cairo as Cairo
import qualified Graphics.Rendering.Cairo.SVG as RSVG
import           System.Directory
import           System.FilePath 
-- from hoodle-platform 
import           Data.Hoodle.BBox 
import           Data.Hoodle.Simple
import           Hoodle.Util.Process 
-- from this package
import Graphics.Hoodle.Render.Type.Item 


-- | construct renderable item 
cnstrctRItem :: Item -> IO RItem 
cnstrctRItem (ItemStroke strk) = return (RItemStroke (runIdentity (makeBBoxed strk)))
cnstrctRItem (ItemImage img) = do 
    let imgbbx = runIdentity (makeBBoxed img)
        src = img_src img
        embed = getByteStringIfEmbeddedPNG src 
    case embed of         
      Just bstr -> do 
        sfc <- saveTempPNGToCreateSurface bstr 
        return (RItemImage imgbbx (Just sfc))
      Nothing -> do
        let filesrc = C8.unpack (img_src img)
            filesrcext = takeExtension filesrc 
            imgaction 
              | filesrcext == ".PNG" || filesrcext == ".png" = do 
                  b <- doesFileExist filesrc 
                  if b then Just <$> Cairo.imageSurfaceCreateFromPNG filesrc
                       else return Nothing 
              | filesrcext == ".JPG" || filesrcext == ".jpg" = do 
                  b <- doesFileExist filesrc 
                  if b then Just <$> getJPGandCreateSurface filesrc 
                       else return Nothing 
              | otherwise = return Nothing 
        msfc <- imgaction
        return (RItemImage imgbbx msfc)
cnstrctRItem (ItemSVG svg@(SVG _ _ bstr _ _)) = do 
    let str = C8.unpack bstr 
        svgbbx = runIdentity (makeBBoxed svg)
    rsvg <- RSVG.svgNewFromString str
    return (RItemSVG svgbbx (Just rsvg))
cnstrctRItem (ItemLink lnk@(Link _ _ _ _ _ bstr _ _)) = do 
    let str = C8.unpack bstr 
        lnkbbx = runIdentity (makeBBoxed lnk)
    rsvg <- RSVG.svgNewFromString str
    return (RItemLink lnkbbx (Just rsvg))
cnstrctRItem (ItemLink lnk@(LinkDocID _ _ _ _ _ bstr _ _)) = do 
    let str = C8.unpack bstr 
        lnkbbx = runIdentity (makeBBoxed lnk)
    rsvg <- RSVG.svgNewFromString str
    return (RItemLink lnkbbx (Just rsvg))    
cnstrctRItem (ItemLink lnk@(LinkAnchor _ _ _ _ _ _)) = do 
    let lnkbbx = runIdentity (makeBBoxed lnk)
    return (RItemLink lnkbbx Nothing)    
cnstrctRItem (ItemAnchor anc@(Anchor _ _ _)) = do 
    let ancbbx = runIdentity (makeBBoxed anc)
    return (RItemAnchor ancbbx)


-- | get embedded png image. If not, just give me nothing. 
getByteStringIfEmbeddedPNG :: C8.ByteString -> Maybe C8.ByteString 
getByteStringIfEmbeddedPNG bstr = do 
    guard (C8.length bstr > 22)
    let (header,dat) = C8.splitAt 22 bstr 
    guard (header == "data:image/png;base64,") 
    either (const Nothing) return (decode dat)


-- | read JPG file using GD library and create cairo image surface
--   currently, this uses temporary png file (which is potentially dangerous)
getJPGandCreateSurface :: FilePath -> IO Cairo.Surface 
getJPGandCreateSurface fp = do 
    img <- loadJpegFile fp  
    bstr <- savePngByteString img
    saveTempPNGToCreateSurface bstr 

-- | 
saveTempPNGToCreateSurface :: C8.ByteString -> IO Cairo.Surface
saveTempPNGToCreateSurface bstr = do 
    pipeActionWith (B.writeFile "/dev/stdout" bstr) Cairo.imageSurfaceCreateFromPNG 

