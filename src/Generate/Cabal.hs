{-# LANGUAGE RecordWildCards #-}
module Generate.Cabal where

import Generate.Monad
import Generate.Splice
import Generate.Splice.Import

import Data.List

import System.Directory
import System.FilePath
import System.IO

import qualified Distribution.ModuleName as Dist

import Distribution.PackageDescription hiding (Var,Lit)
import Distribution.PackageDescription.Parse
import qualified Distribution.Verbosity as Verbosity

import Distribution.PackageDescription.PrettyPrint
import Distribution.PackageDescription.Configuration
import Distribution.Package
import Distribution.Version

import qualified Language.Haskell.Extension as Ext
import qualified Language.Haskell.Exts.Syntax as Ext

import Prelude hiding (log)

thisMopDependency :: Dependency
thisMopDependency = Dependency (PackageName "mop")
                               (orLaterVersion (Version [0,2,1] []))

mopDirectory :: FilePath
mopDirectory = "mop"

findCabalFile :: FilePath -> IO FilePath
findCabalFile d
  | null d || d == "/" = do
     cwd <- getCurrentDirectory
     error $ "Could not find cabal file above " ++ cwd
  | otherwise = do
     dc <- getDirectoryContents d
     let fs = [ x | x <- dc
                  , takeExtensions x == ".cabal"
                  ]
     if not (null fs)
     then return (d </> head fs)
     else findCabalFile (takeDirectory d)

readCabalFileIO :: FilePath -> IO GenericPackageDescription
readCabalFileIO = readPackageDescription Verbosity.normal

readCabalFile :: Mop GenericPackageDescription
readCabalFile = do
  cf <- gets cabalFile
  io $ readPackageDescription Verbosity.normal cf

writeCabalFile :: Mop ()
writeCabalFile = do
  cf <- gets cabalFile
  gpd <- gets currentPackageDesc
  io $ writeGenericPackageDescription cf gpd

modifyGPD :: (GenericPackageDescription -> Mop GenericPackageDescription) -> Mop ()
modifyGPD f = do
  MopState pkg fp hsem ds <- get
  pkg' <- f pkg
  put (MopState pkg' fp hsem ds)

modifyPD :: (PackageDescription -> Mop PackageDescription) -> Mop ()
modifyPD f = modifyGPD $ \gpd -> do
  pd <- f (packageDescription gpd)
  return $ gpd { packageDescription = pd }

-- needs extension to work over the CondTree rather than the root
modifyCondLibrary :: (Library -> Mop Library) -> Mop ()
modifyCondLibrary f = modifyGPD $ \gpd -> do
  case condLibrary gpd of
    Nothing -> do
      log Notify "No library found in cabal file; generating new empty library."
      l <- f emptyLibrary
      return (gpd { condLibrary = Just (CondNode l [thisMopDependency] []) })
    Just (CondNode lib deps components) -> do
      l <- f lib
      return (gpd { condLibrary = Just (CondNode l deps components) })

modifyLibBuildInfo :: (BuildInfo -> Mop BuildInfo) -> Mop ()
modifyLibBuildInfo f = modifyCondLibrary $ \lib -> do
  bi <- f (libBuildInfo lib)
  return $ lib { libBuildInfo = bi }

modifySourceDirs :: ([FilePath] -> Mop [FilePath]) -> Mop ()
modifySourceDirs f = modifyLibBuildInfo $ \lbi -> do
  sds <- f (hsSourceDirs lbi)
  return $ lbi { hsSourceDirs = sds }
guaranteeSourceDir :: FilePath -> Mop ()
guaranteeSourceDir fp = do
  io (createDirectoryIfMissing True fp)
  modifySourceDirs (return . nub . (fp:))

modifyBuildDepends :: ([Dependency] -> Mop [Dependency]) -> Mop ()
modifyBuildDepends f = modifyPD $ \pd -> do
  bd <- f (buildDepends pd)
  return $ pd { buildDepends = bd }

modifyOtherModules :: ([Dist.ModuleName] -> Mop [Dist.ModuleName]) -> Mop ()
modifyOtherModules f = modifyLibBuildInfo $ \lbi -> do
  om <- f (otherModules lbi)
  return $ lbi { otherModules = om }

modifyVersion :: (Version -> Mop Version) -> Mop ()
modifyVersion f = modifyPD $ \pd -> do
  let p = package pd
  v <- f (pkgVersion p)
  return $ pd { package = p { pkgVersion = v }}

incrementMilestone :: Version -> Mop Version
incrementMilestone (Version (milestone:vs) ts) = return (Version (succ milestone:vs) ts)

incrementMajor :: Version -> Mop Version
incrementMajor (Version [v] ts) = return (Version [v,1] ts)
incrementMajor (Version (v:major:vs) ts) = return (Version (v:succ major:vs) ts)

incrementMinor :: Version -> Mop Version
incrementMinor (Version [v0] ts) = return (Version [v0,0,1] ts)
incrementMinor (Version [v0,v1] ts) = return (Version [v0,v1,1] ts)
incrementMinor (Version (v0:v1:minor:vs) ts) = return (Version (v0:v1:succ minor:vs) ts)

incrementPatch :: Version -> Mop Version
incrementPatch (Version [v0] ts) = return (Version [v0,0,0,1] ts)
incrementPatch (Version [v0,v1] ts) = return (Version [v0,v1,0,1] ts)
incrementPatch (Version [v0,v1,v2] ts) = return (Version [v0,v1,v2,1] ts)
incrementPatch (Version (v0:v1:v2:patch:vs) ts) = return (Version (v0:v1:v2:succ patch:vs) ts)

guaranteeOtherModule :: Dist.ModuleName -> Mop ()
guaranteeOtherModule m = modifyOtherModules (return . nub . (m:))

addOtherModule :: Dist.ModuleName -> Mop ()
addOtherModule = guaranteeOtherModule

removeOtherModule :: Dist.ModuleName -> Mop ()
removeOtherModule m = modifyOtherModules (return . filter (/=m))

modifyExposedModules :: ([Dist.ModuleName] -> Mop [Dist.ModuleName]) -> Mop ()
modifyExposedModules f = modifyCondLibrary $ \l -> do
  em <- f (exposedModules l)
  return $ l { exposedModules = em }

guaranteeExposedModule :: Dist.ModuleName -> Mop ()
guaranteeExposedModule m = modifyExposedModules (return . nub . (m:))

addExposedModule :: Dist.ModuleName -> Mop ()
addExposedModule = guaranteeExposedModule

removeExposedModule :: Dist.ModuleName -> Mop ()
removeExposedModule m = modifyExposedModules (return . filter (/=m))

--------------------------------------------------------------------------------
-- Language Extensions (pragmas) in cabal files

quasiQuotes = Ext.EnableExtension Ext.QuasiQuotes

templateHaskell = Ext.EnableExtension Ext.TemplateHaskell

typeOperators = Ext.EnableExtension Ext.TypeOperators

noMonomorphismRestriction = Ext.UnknownExtension "NoMonomorphismRestriction"

flexibleContexts = Ext.EnableExtension Ext.FlexibleContexts

deriveFunctor = Ext.EnableExtension Ext.DeriveFunctor

patternSynonyms = Ext.EnableExtension Ext.PatternSynonyms

existentialQuantification = Ext.EnableExtension Ext.ExistentialQuantification

kindSignatures = Ext.EnableExtension Ext.KindSignatures

modifyDefaultExtensions :: ([Ext.Extension] -> Mop [Ext.Extension]) -> Mop ()
modifyDefaultExtensions f = modifyLibBuildInfo $ \lbi -> do
  de <- f (defaultExtensions lbi)
  return $ lbi { defaultExtensions = de }

guaranteeDefaultExtension :: Ext.Extension -> Mop ()
guaranteeDefaultExtension e = modifyDefaultExtensions $ \es -> return $ nub (e:es)

addDefaultExtension :: Ext.Extension -> Mop ()
addDefaultExtension e = modifyDefaultExtensions (return . nub . (e:))

removeDefaultExtension :: Ext.Extension -> Mop ()
removeDefaultExtension e = modifyDefaultExtensions (return . filter (/=e))

modifyOtherExtensions :: ([Ext.Extension] -> Mop [Ext.Extension]) -> Mop ()
modifyOtherExtensions f = modifyLibBuildInfo $ \lbi -> do
  oe <- f (otherExtensions lbi)
  return $ lbi { otherExtensions = oe }

guaranteeOtherExtension :: Ext.Extension -> Mop ()
guaranteeOtherExtension e = modifyOtherExtensions $ \es ->
  return $ nub (e:es)

addOtherExtension :: Ext.Extension -> Mop ()
addOtherExtension e = modifyOtherExtensions (return . nub . (e:))

removeOtherExtension :: Ext.Extension -> Mop ()
removeOtherExtension e = modifyDefaultExtensions (return . filter (/=e))

writeModule :: Module -> Mop ()
writeModule  m@(Module sl@(SrcLoc fp _ _) _ _ _ _ _ _) = do
  io $ do
    createDirectoryIfMissing True $ takeDirectory fp
    h <- openFile fp WriteMode
    hClose h

  void (splice sl m)

createEmptyModule :: Dist.ModuleName -> FilePath -> Mop Module
createEmptyModule mn dir = do
  d <- gets (takeDirectory . cabalFile)
  let f = d </> dir </> Dist.toFilePath mn <.> "hs"
      m = Module (SrcLoc f 1 1)
                 (Ext.ModuleName (intercalate "." $ Dist.components mn))
                 []
                 Nothing
                 Nothing
                 [simpleImport (ModuleName "Mop") (SrcLoc f 2 1)]
                 []
  return m
