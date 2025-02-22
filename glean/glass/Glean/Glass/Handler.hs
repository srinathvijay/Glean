{-
  Copyright (c) Meta Platforms, Inc. and affiliates.
  All rights reserved.

  This source code is licensed under the BSD-style license found in the
  LICENSE file in the root directory of this source tree.
-}

{-# LANGUAGE ApplicativeDo #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE ConstraintKinds #-}
{-# OPTIONS_GHC -Wno-orphans #-}

module Glean.Glass.Handler
  (
  -- * listing symbols by file
    documentSymbolListX
  , documentSymbolIndex
  -- ** resolving spans to files
  , jumpTo

  -- ** find references
  , findReferences
  , findReferenceRanges

  -- * working with symbol ids
  , resolveSymbol
  , describeSymbol

  -- * searching
  -- ** by identifier
  , searchByName
  , searchByNamePrefix
  -- ** by symbolid fragments
  , searchBySymbolId
  -- ** by relationship
  , searchRelated

  -- * indexing requests
  , index
  ) where

import Control.Concurrent.STM ( TVar )
import Control.Exception ( throwIO, SomeException )
import Control.Monad ( when, forM )
import Control.Monad.Catch ( throwM, try )
import Data.Either.Extra (eitherToMaybe, partitionEithers)
import Data.Foldable ( forM_ )
import Data.List.NonEmpty (NonEmpty(..), toList)
import Data.Maybe ( fromMaybe, catMaybes )
import Data.Text ( Text )
import qualified Data.List as List
import qualified Data.Map as Map
import qualified Data.Text as Text

import Logger.GleanGlass ( GleanGlassLogger )
import Logger.GleanGlassErrors ( GleanGlassErrorsLogger )
import Util.Logger ( loggingAction )
import Util.Text ( textShow )
import Util.Control.Exception (catchAll)
import qualified Logger.GleanGlass as Logger
import qualified Logger.GleanGlassErrors as ErrorsLogger

import Thrift.Protocol ( fromThriftEnum )
import Thrift.Api (Thrift)

import Glean.Angle as Angle ( Angle )
import Glean.Backend.Remote ( ThriftBackend(..), thriftServiceWithTimeout )
import qualified Glean
import Glean.Haxl.Repos as Glean
import qualified Glean.Repo as Glean
import qualified Glean.Util.Some as Glean
import qualified Glean.Util.Range as Range
import Glean.Util.ThriftService ( ThriftServiceOptions(..), runThrift )

import qualified Glean.Schema.Codemarkup.Types as Code
import qualified Glean.Schema.Code.Types as Code
import qualified Glean.Schema.Src.Types as Src

import qualified Control.Concurrent.Async as Async

import qualified Glean.Glass.Attributes as Attributes
import Glean.Glass.Base
    ( GleanPath(..) )
import Glean.Glass.Logging
    ( LogRepo(..),
      ErrorTy(..),
      LogResult(..),
      LogRequest(..),
      LogError(..),
      ErrorLogger, errorText )
import Glean.Glass.Repos
    ( GleanDBName(unGleanDBName),
      firstAttrDB,
      filetype,
      findLanguages,
      findRepos,
      fromSCSRepo,
      lookupLatestRepos,
      toRepoName,
      filterRepoLang,
      GleanDBAttrName(GleanDBAttrName, gleanAttrDBName) )
import Glean.Glass.Path
    ( toGleanPath )
import Glean.Glass.Range
    ( locationFromCodeLocation,
      locationRangeFromCodeLocation,
      toLocationRange,
      rangeSpanToRange,
      fileByteSpanToExclusiveRange,
      memoLineOffsets,
      getFile,
      getFileAndLines,
      toLocation,
      resolveLocationToRange,
      FileInfo(FileInfo, offsets, srcFile, fileId, fileRepo) )
import Glean.Glass.SymbolId
    ( entityToAngle,
      symbolTokens,
      toQualifiedName,
      toShortCode,
      toSymbolId,
      entityDefinitionType,
      entityLanguage,
      entityKind,
      fromShortCode )
import Glean.Glass.SymbolId.Class
    ( ToSymbolParent(toSymbolParent) )
import Glean.Glass.SymbolSig
    ( ToSymbolSignature(toSymbolSignature) )
import Glean.Glass.SymbolKind ( findSymbolKind )
import Glean.Glass.Types
    ( SearchContext(searchContext_kinds, searchContext_repo_name,
                    searchContext_language),
      SymbolPath(SymbolPath, symbolPath_range, symbolPath_repository,
                 symbolPath_filepath),
      Attribute(Attribute_aInteger, Attribute_aString),
      KeyedAttribute(KeyedAttribute),
      Name(Name),
      AttributeList(AttributeList),
      Attributes,
      DefinitionSymbolX(DefinitionSymbolX),
      ReferenceRangeSymbolX(ReferenceRangeSymbolX),
      SearchBySymbolIdResult(SearchBySymbolIdResult),
      SearchByNameResult(..),
      SearchByNameRequest(..),
      SearchRelatedRequest(..),
      SearchRelatedResult(..),
      ServerException(ServerException),
      SymbolDescription(..),
      SymbolId(SymbolId),
      Range,
      Location(..),
      LocationRange(..),
      DocumentSymbolIndex(..),
      DocumentSymbolListXResult(DocumentSymbolListXResult),
      Language(Language_Cpp),
      Revision(Revision),
      Path,
      RepoName(..),
      RequestOptions(..),
      DocumentSymbolsRequest(..), SymbolKind,
      rELATED_SYMBOLS_MAX_LIMIT )
import Glean.Index.Types
  ( IndexRequest,
    IndexResponse)
import qualified Glean.Index.GleanIndexingService.Client as IndexingService
import Glean.Index.GleanIndexingService.Client ( GleanIndexingService )
import Glean.Impl.ThriftService ( ThriftService )

import qualified Glean.Glass.Env as Glass

import qualified Glean.Glass.Query as Query
import qualified Glean.Glass.Query.Cxx as Cxx

import Glean.Glass.SymbolMap ( toSymbolIndex )
import Glean.Glass.Search as Search
    ( searchEntity,
      SearchEntity(SearchEntity, rangespan, file, decl, entityRepo),
      SearchResult(Many, None, One), prefixSearchEntity )
import Glean.Glass.Utils
    ( searchRecursiveWithLimit, QueryType, searchReposWithLimit )
import qualified Data.Set as Set
import Glean.Glass.Attributes.SymbolKind
    ( symbolKindFromSymbolKind, symbolKindToSymbolKind )
import Glean.Glass.Annotations (getAnnotationsForEntity)
import Glean.Glass.Comments (getCommentsForEntity)
import Glean.Glass.SearchRelated (searchRelatedSymbols, Recursive(..))


-- | Runner for methods that are keyed by a file path
-- TODO : do the plumbing via a class rather than function composition
runRepoFile
  :: (LogResult t)
  => Text
  -> ( TVar Glean.LatestRepos
    -> DocumentSymbolsRequest
    -> RequestOptions
    -> GleanBackend (Glean.Some Glean.Backend)
    -> Maybe Language
    -> IO (t, Maybe ErrorLogger))
  -> Glass.Env
  -> DocumentSymbolsRequest
  -> RequestOptions
  -> IO t
runRepoFile sym fn env req opts =
  withRepoFile sym env req repo file $ \dbs mlang ->
    fn repos req opts
        (mkGleanBackend (Glass.gleanBackend env) dbs)
          mlang
  where
    repos = Glass.latestGleanRepos env
    repo = documentSymbolsRequest_repository req
    file = documentSymbolsRequest_filepath req

-- | Discover navigable symbols in this file, resolving all bytespans and
-- adding any attributes
documentSymbolListX
  :: Glass.Env
  -> DocumentSymbolsRequest
  -> RequestOptions
  -> IO DocumentSymbolListXResult
documentSymbolListX = runRepoFile "documentSymbolListX"
  fetchSymbolsAndAttributes

-- | Same as documentSymbolList() but construct a line-indexed map for easy
-- cursor/position lookup, and add extra metadata
documentSymbolIndex
  :: Glass.Env
  -> DocumentSymbolsRequest
  -> RequestOptions
  -> IO DocumentSymbolIndex
documentSymbolIndex = runRepoFile "documentSymbolIndex" fetchDocumentSymbolIndex

firstOrErrors
  :: ReposHaxl u w [Either ErrorTy a] -> ReposHaxl u w (Either ErrorTy a)
firstOrErrors act = do
  result <- act
  let (fail, success) = partitionEithers result
  return $ case success of
    x:_ -> Right x
    [] -> Left $ AggregateError fail

-- | Given a Location , resolve it to a line:col range in the target file
jumpTo
  :: Glass.Env
  -> Location
  -> RequestOptions
  -> IO Range
jumpTo env@Glass.Env{..} req@Location{..} _opts =
  withRepoFile "jumpTo" env req repo file
    (\gleanDBs _lang -> backendRunHaxl GleanBackend{..} $ do
      result <-
        firstOrErrors $ queryEachRepo $ do
          repo <- Glean.haxlRepo
          resolveLocationToRange repo req
      case result of
        Left err -> throwM $ ServerException $ errorText err
        Right efile -> return (efile, Nothing))
  where
    repo = location_repository
    file = location_filepath

-- | Symbol-based find-refernces.
findReferences
  :: Glass.Env
  -> SymbolId
  -> RequestOptions
  -> IO [Location]
findReferences env@Glass.Env{..} sym RequestOptions{..} =
  withSymbol "findReferences" env sym (\(dbs,(repo, lang, toks)) ->
    fetchSymbolReferences repo lang toks limit
      (mkGleanBackend gleanBackend dbs))
  where
    limit = fmap fromIntegral requestOptions_limit

-- | Symbol-based find-refernces.
findReferenceRanges
  :: Glass.Env
  -> SymbolId
  -> RequestOptions
  -> IO [LocationRange]
findReferenceRanges env@Glass.Env{..} sym RequestOptions{..} =
  withSymbol "findReferenceRanges" env sym $ \(db,(repo, lang, toks)) ->
    fetchSymbolReferenceRanges repo lang toks limit
      (mkGleanBackend gleanBackend db)
  where
    limit = fmap fromIntegral requestOptions_limit

-- | Resolve a symbol identifier to its location in the latest db (or older
-- revision if specified)
resolveSymbol
  :: Glass.Env
  -> SymbolId
  -> RequestOptions
  -> IO Location
resolveSymbol env@Glass.Env{..} sym _opts =
  withSymbol "resolveSymbol" env sym (\(db,(repo, lang, toks)) ->
    findSymbolLocation repo lang toks (mkGleanBackend gleanBackend db))

-- | Describe characteristics of a symbol
describeSymbol
  :: Glass.Env
  -> SymbolId
  -> RequestOptions
  -> IO SymbolDescription
describeSymbol env@Glass.Env{..} sym_id _opts =
  withSymbol "describeSymbol" env sym_id $ \(gleanDBs, (repo, lang, toks)) -> do
    backendRunHaxl GleanBackend{..} $ do
      r <- Search.searchEntity lang toks
      (SearchEntity{..}, err) <- case r of
        None t -> throwM (ServerException t)
        One e -> return (e, Nothing)
        Many e _t -> return (e, Nothing)
      loc <- withRepo entityRepo $
        locationRangeFromCodeLocation repo file rangespan
      kind <- withRepo entityRepo $ eitherToMaybe <$> findSymbolKind decl
      desc <- withRepo entityRepo $ describeEntity loc decl sym_id kind
      return (desc, err)

-- | Search for entities by string fragments of names
searchByName
  :: Glass.Env
  -> SearchByNameRequest
  -> RequestOptions
  -> IO SearchByNameResult
searchByName = searchEntityByString "searchByName" Query.searchByLocalName

-- | Search for entities by string fragments of names
searchByNamePrefix
  :: Glass.Env
  -> SearchByNameRequest
  -> RequestOptions
  -> IO SearchByNameResult
searchByNamePrefix =
  searchEntityByString "searchByNamePrefix" Query.searchByLocalNamePrefix

-- | Search for entities by symbol id prefix
searchBySymbolId
  :: Glass.Env
  -> SymbolId
  -> RequestOptions
  -> IO SearchBySymbolIdResult
searchBySymbolId env@Glass.Env{..} symbolPrefix opts = do
  withLog "searchBySymbolId" env symbolPrefix $ \log -> do
    symids <- case partialSymbolTokens symbolPrefix of
          (Left pRepo, Left _, []) -> pure $ findRepos pRepo
          (Left pRepo, _, _) -> throwM $
            ServerException $ pRepo <> " is not a known repo"
          (Right repo, Left pLang, []) -> pure $
            findLanguages repo $ fromMaybe (Text.pack "") pLang
          (Right (RepoName repo), Left (Just pLang), _) -> throwM $
            ServerException $ pLang <> " is not a supported language in "<> repo
          (Right (RepoName repo), Left Nothing, _) -> throwM $
            ServerException $ "Missing language for " <> repo
          (Right repo, Right lang, tokens) -> findSymbols repo lang tokens
    return (SearchBySymbolIdResult symids, log, Nothing)

  where
    findSymbols :: RepoName -> Language -> [Text] -> IO [SymbolId]
    findSymbols repo lang tokens =
      withRepoLanguage "findSymbols" env symbolPrefix repo (Just lang) $
        \gleanDBs _ -> do
          backendRunHaxl GleanBackend{..} $ do
            symids <-  queryAllRepos $ do
              entities <- prefixSearchEntity lang limit tokens
              mapM (toSymbolId repo) $ take limit entities
            return (take limit symids, Nothing)
    limit = maybe 50 fromIntegral $ requestOptions_limit opts

-- | Normalized (to Glean) paths
data FileReference =
  FileReference {
    _repoName :: !RepoName,
    theGleanPath :: !GleanPath
  }

toFileReference :: RepoName -> Path -> FileReference
toFileReference repo path = FileReference repo (toGleanPath repo path)

-- | Bundle of glean db handle resources
data GleanBackend b =
  GleanBackend {
    gleanBackend :: b,
    gleanDBs :: NonEmpty (GleanDBName, Glean.Repo)
  }
backendRunHaxl
  :: Glean.Backend b => GleanBackend b -> (forall u. ReposHaxl u w a) -> IO a
backendRunHaxl GleanBackend {..} act =
  runHaxlAllRepos gleanBackend (fmap snd gleanDBs) act

mkGleanBackend
  :: Glean.Backend b
  => b
  -> NonEmpty (GleanDBName, Glean.Repo)
  -> GleanBackend b
mkGleanBackend b dbs = GleanBackend b dbs

-- | Symbol search: try to resolve the symbol back to an Entity.
findSymbolLocation
  :: Glean.Backend b
  => RepoName
  -> Language
  -> [Text]
  -> GleanBackend b
  -> IO (Location, Maybe ErrorLogger)
findSymbolLocation scsrepo lang toks b =
  backendRunHaxl b $ do
    r <- Search.searchEntity lang toks
    (SearchEntity{..}, err) <- case r of
      None t -> throwM (ServerException t)
      One e ->  return (e, Nothing)
      Many e t -> return (e, Just (EntitySearchFail t))
    (, fmap logError err) <$> withRepo entityRepo
      (locationFromCodeLocation scsrepo file rangespan)

-- | Symbol search for references
fetchSymbolReferences
  :: Glean.Backend b
  => RepoName
  -> Language
  -> [Text]
  -> Maybe Int
  -> GleanBackend b
  -> IO ([Location], Maybe ErrorLogger)
fetchSymbolReferences scsrepo lang toks limit b =
  backendRunHaxl b $ do
    er <- symbolToAngleEntity lang toks
    case er of
      Left err -> return ([], Just err)
      Right (query, searchErr) -> do
        locs::[Location] <-
          searchReposWithLimit limit (Query.findReferences query) $
            \(file, bytespan) ->
              toLocation scsrepo file bytespan
        return (locs, fmap logError searchErr)

-- | Symbol search for references as ranges
fetchSymbolReferenceRanges
  :: Glean.Backend b
  => RepoName
  -> Language
  -> [Text]
  -> Maybe Int
  -> GleanBackend b
  -> IO ([LocationRange], Maybe ErrorLogger)
fetchSymbolReferenceRanges scsrepo lang toks limit b =
  backendRunHaxl b $ do
    er <- symbolToAngleEntity lang toks
    case er of
      Left err -> return ([], Just err)
      Right (query, searchErr) ->  do
        ranges <- searchReposWithLimit limit (Query.findReferences query) $
          \(targetFile, span) -> do
            -- memo convert all spans to ranges
            moffsets <- memoLineOffsets targetFile
            toLocationRange scsrepo targetFile $
              fileByteSpanToExclusiveRange targetFile moffsets span
        return (ranges, fmap logError searchErr)

-- | Search for a symbol and return an Angle query that identifies the entity
symbolToAngleEntity
  :: Language
  -> [Text]
  -> ReposHaxl u w
      (Either
        GleanGlassErrorsLogger
        (Angle Code.Entity, Maybe ErrorTy))
symbolToAngleEntity lang toks = do
  r <- Search.searchEntity lang toks
  (SearchEntity{..}, searchErr) <- case r of
    None t -> throwM (ServerException t) -- return [] ?
    One e -> return (e, Nothing)
    Many e t -> return (e, Just (EntitySearchFail t))
  return $ case entityToAngle decl of
      Left err -> Left (logError (EntityNotSupported err))
      Right query -> Right (query, searchErr)

-- Find all symbols and refs in file and add all attributes
fetchSymbolsAndAttributes
  :: Glean.Backend b
  => TVar Glean.LatestRepos
  -> DocumentSymbolsRequest
  -> RequestOptions
  -> GleanBackend b
  -> Maybe Language
  -> IO (DocumentSymbolListXResult, Maybe ErrorLogger)
fetchSymbolsAndAttributes latest req opts be mlang = do
  let
    file = toFileReference
      (documentSymbolsRequest_repository req)
      (documentSymbolsRequest_filepath req)
    mlimit = fmap fromIntegral (requestOptions_limit opts)
    includeRefs = documentSymbolsRequest_include_refs req
  (res1, logs) <- fetchDocumentSymbols file mlimit includeRefs be mlang
  res2 <- addDynamicAttributes latest file mlimit be res1
  return (res2, logs)

-- Find all references and definitions in the file
fetchDocumentSymbols
  :: Glean.Backend b
  => FileReference
  -> Maybe Int
  -> Bool  -- ^ include references?
  -> GleanBackend b
  -> Maybe Language
  -> IO (DocumentSymbols, Maybe ErrorLogger)

fetchDocumentSymbols (FileReference scsrepo path)
    mlimit includeRefs b mlang =
  backendRunHaxl b $ do
    efile <- firstOrErrors $ queryEachRepo $ do
      repo <- Glean.haxlRepo
      getFileAndLines repo path

    case efile of
      Left err ->
        return $ (, Just (logError err)) $
          DocumentSymbols [] [] (revision b)
        where
          -- Use first db's revision
          revision GleanBackend {gleanDBs = ((_, repo) :| _)} =
            Revision $ Glean.repo_hash repo

      Right FileInfo{..} -> do

      -- from Glean, fetch xrefs and defs in batches
      (xrefs,defns) <- withRepo fileRepo $
        documentSymbolsForLanguage mlimit mlang
          includeRefs fileId
      (kindMap, merr) <- withRepo fileRepo $
        documentSymbolKinds mlimit mlang fileId

      -- mark up symbols into normal format with static attributes
      refs1 <- withRepo fileRepo $
        mapM (\x -> toReferenceSymbol scsrepo srcFile offsets x) xrefs
      defs1 <- withRepo fileRepo $
        mapM (\x -> toDefinitionSymbol scsrepo srcFile offsets x) defns

      let (refs, defs) = Attributes.extendAttributes
            (Attributes.fromSymbolId Attributes.SymbolKindAttr)
              kindMap refs1 defs1
      let revision = Revision (Glean.repo_hash fileRepo)

      return (DocumentSymbols {..}, merr)

-- | Wrapper for tracking symbol/entity pairs through processing
data DocumentSymbols = DocumentSymbols
  { refs :: [(Code.Entity, ReferenceRangeSymbolX)]
  , defs :: [(Code.Entity, DefinitionSymbolX)]
  , revision :: !Revision
  }

-- | Drop any remnant entities after we are done with them
toDocumentSymbolResult :: DocumentSymbols -> DocumentSymbolListXResult
toDocumentSymbolResult DocumentSymbols{..} = DocumentSymbolListXResult
  (map snd refs) (map snd defs) revision

--
-- | Check if this db / lang pair has additional dynamic attributes
-- and add them if so
--
addDynamicAttributes
  :: Glean.Backend b
  => TVar Glean.LatestRepos
  -> FileReference
  -> Maybe Int
  -> GleanBackend b
  -> DocumentSymbols
  -> IO DocumentSymbolListXResult
addDynamicAttributes latestRepos repofile mlimit be syms = do
  -- combine additional dynamic attributes
  mattrs <- getSymbolAttributes latestRepos repofile mlimit be
  return $ extend mattrs syms
  where
    extend [] syms = toDocumentSymbolResult syms
    extend ((GleanDBAttrName _ attrKey, attrMap) : xs) syms =
      let keyFn = Attributes.fromSymbolId attrKey
          (refs',defs') = Attributes.extendAttributes keyFn attrMap
            (refs syms)
            (defs syms)
      in extend xs $ syms { refs = refs' , defs = defs' }

type XRefs = [(Code.XRefLocation,Code.Entity)]
type Defns = [(Code.Location,Code.Entity)]

-- | Which fileEntityLocations and fileEntityXRefLocation implementations to use
documentSymbolsForLanguage
  :: Maybe Int
  -> Maybe Language
  -> Bool  -- ^ include references?
  -> Glean.IdOf Src.File
  -> Glean.RepoHaxl u w (XRefs, Defns)

-- For Cpp, we need to do a bit of client-side processing
documentSymbolsForLanguage mlimit (Just Language_Cpp) includeRefs fileId =
  Cxx.documentSymbolsForCxx mlimit includeRefs fileId

-- For everyone else, we just query the generic codemarkup predicates
documentSymbolsForLanguage mlimit _ includeRefs fileId = do
  xrefs <- if includeRefs
    then searchRecursiveWithLimit mlimit $
      Query.fileEntityXRefLocations fileId
    else return []
  defns <- searchRecursiveWithLimit mlimit $
    Query.fileEntityLocations fileId
  return (xrefs,defns)

-- And build a line-indexed map of symbols, resolved to spans
-- With extra attributes loaded from any associated attr db
fetchDocumentSymbolIndex
  :: Glean.Backend b
  => TVar Glean.LatestRepos
  -> DocumentSymbolsRequest
  -> RequestOptions
  -> GleanBackend b
  -> Maybe Language
  -> IO (DocumentSymbolIndex, Maybe ErrorLogger)
fetchDocumentSymbolIndex latest req opts be mlang = do
  (DocumentSymbolListXResult refs defs revision, merr1) <-
    fetchSymbolsAndAttributes latest req opts be mlang

  return $ (,merr1) DocumentSymbolIndex {
    documentSymbolIndex_symbols = toSymbolIndex refs defs,
    documentSymbolIndex_revision = revision,
    documentSymbolIndex_size = fromIntegral $ length defs + length refs
  }

-- Work out if we have extra attribute dbs and then run the queries
getSymbolAttributes
  :: Glean.Backend b
  => TVar Glean.LatestRepos
  -> FileReference
  -> Maybe Int
  -> GleanBackend b
  -> IO
     [(GleanDBAttrName, Map.Map Attributes.SymbolIdentifier Attributes)]
getSymbolAttributes repos repofile mlimit be@GleanBackend{..} = do
  mAttrDBs <- forM (map fst $ toList gleanDBs) $ getLatestAttrDB repos
  attrs <- backendRunHaxl be $ do
    forM (catMaybes mAttrDBs) $
      \(attrDB, attr@(GleanDBAttrName _ attrKey){- existential key -}) ->
        withRepo attrDB $ do
        (attrMap,_merr2) <- genericFetchFileAttributes attrKey
          (theGleanPath repofile) mlimit
        return $ Just (attr, attrMap)
  return $ catMaybes attrs

-- | Same repo generic attributes
documentSymbolKinds
  :: Maybe Int
  -> Maybe Language
  -> Glean.IdOf Src.File
  -> Glean.RepoHaxl u w
     (Map.Map Attributes.SymbolIdentifier Attributes, Maybe ErrorLogger)

-- It's not sound to key for all entities in file in C++ , due to traces
-- So we can't use the generic a attribute technique
documentSymbolKinds _mlimit (Just Language_Cpp) _fileId =
  return mempty

-- Anything else, just load from Glean
documentSymbolKinds mlimit _ fileId =
  searchFileAttributes Attributes.SymbolKindAttr mlimit fileId

-- \ External (non-local db) Attributes of symbols. Just Hack only for now
genericFetchFileAttributes
  :: (QueryType (Attributes.AttrRep key)
     , Attributes.ToAttributes key)
  => key
  -> GleanPath
  -> Maybe Int
  -> RepoHaxl u w
      (Map.Map Attributes.SymbolIdentifier Attributes, Maybe ErrorLogger)

genericFetchFileAttributes key path mlimit = do
  efile <- getFile path
  case efile of
    Left err ->
      return (mempty, Just (logError err))
    Right fileId -> do
      searchFileAttributes key mlimit (Glean.getId fileId)

searchFileAttributes
  :: (QueryType (Attributes.AttrRep key), Attributes.ToAttributes key)
  => key
  -> Maybe Int
  -> Glean.IdOf Src.File
  -> Glean.RepoHaxl u w
    (Map.Map Attributes.SymbolIdentifier Attributes, Maybe ErrorLogger)
searchFileAttributes key mlimit fileId = do
  eraw <- try $ Attributes.searchBy key mlimit $
                Attributes.queryFileAttributes key fileId
  case eraw of
    Left (err::SomeException) -- logic errors or transient errors
      -> return (mempty, Just (logError $ AttributesError $ textShow err))
    Right raw
      -> return (Attributes.toAttrMap key raw, Nothing)

-- | Like toReferenceSymbol but we convert the xref target to a src.Range
toReferenceSymbol
  :: RepoName
  -> Src.File
  -> Maybe Range.LineOffsets
  -> (Code.XRefLocation, Code.Entity)
  -> Glean.RepoHaxl u w (Code.Entity, ReferenceRangeSymbolX)
toReferenceSymbol repoName file offsets (Code.XRefLocation{..},entity) = do

  sym <- toSymbolId repoName entity
  attributes <- getStaticAttributes entity

  moffsets <- memoLineOffsets location_file
  let targetRange = rangeSpanToRange location_file moffsets location_location
      targetNameRange =
        fmap (fileByteSpanToExclusiveRange location_file moffsets) location_span

  target <- toLocationRange repoName location_file targetRange
  return $ (entity,)
    $ ReferenceRangeSymbolX sym range target attributes targetNameRange
  where
    -- reference target is a Declaration and an Entity
    Code.Location{..} = xRefLocation_target
    -- resolved the local span to a location
    range = rangeSpanToRange file offsets xRefLocation_source

-- | Building a resolved definition symbol is just taking a direct xref to it,
-- and converting the bytespan, adding any static attributes
toDefinitionSymbol
  :: RepoName
  -> Src.File
  -> Maybe Range.LineOffsets
  -> (Code.Location, Code.Entity)
  -> Glean.RepoHaxl u w (Code.Entity, DefinitionSymbolX)
toDefinitionSymbol repoName file offsets (Code.Location{..}, entity) = do
  sym <- toSymbolId repoName entity
  attributes <- getStaticAttributes entity
  return $ (entity,) $ DefinitionSymbolX sym range attributes nameRange
  where
    range = rangeSpanToRange file offsets location_location
    nameRange = fmap (fileByteSpanToExclusiveRange file offsets) location_span

-- | Decorate an entity with 'static' attributes.
-- These are static in that they are derivable from the entity and
-- schema information alone, without additional repos
--
getStaticAttributes :: Code.Entity -> Glean.RepoHaxl u w AttributeList
getStaticAttributes e = do
  mParent <- toSymbolParent e -- the "parent" of the symbol
  mSignature <- toSymbolSignature e -- optional type signature
  mKind <- entityKind e -- optional glass-side symbol kind labels
  return $ AttributeList $ map (\(a,b) -> KeyedAttribute a b) $ catMaybes
    [ asParentAttr <$> mParent
    , asSignature  <$> mSignature
    , asKind <$> mKind
    , Just $ asLanguage (entityLanguage e)
    , asDefinitionType <$> entityDefinitionType e
    ]
  where
    asParentAttr (Name x) = ("symbolParent", Attribute_aString x)
    asSignature sig = ("symbolSignature", Attribute_aString sig)
    asKind kind = ("symbolKind",
      Attribute_aInteger (fromIntegral $ fromThriftEnum kind))
    asLanguage lang = ("symbolLanguage",
      Attribute_aInteger (fromIntegral $ fromThriftEnum lang))
    asDefinitionType kind = ("symbolDefinitionType",
      Attribute_aInteger (fromIntegral $ fromThriftEnum kind))

-- | Given an SCS repo name, and a candidate path, find latest Glean dbs or
-- throw. Returns the chosen db name and Glean repo handle
getGleanRepos
  :: TVar Glean.LatestRepos
  -> RepoName
  -> Maybe Language
  -> IO (NonEmpty (GleanDBName,Glean.Repo))
getGleanRepos repos scsrepo mlanguage = do
  let gleanDBNames = fromSCSRepo scsrepo mlanguage

  when (List.null gleanDBNames) $
    throwIO $ ServerException $ "No repository found for: " <>
      unRepoName scsrepo <>
        maybe "" (\x -> " (" <> toShortCode x <> ")") mlanguage

  dbs <- lookupLatestRepos repos gleanDBNames
  case dbs of
    [] -> throwIO $ ServerException $ "No Glean dbs found for: " <>
            Text.intercalate ", " (map unGleanDBName gleanDBNames)

    db:dbs -> return $ db :| dbs

-- | Get glean db for an attribute type
getLatestAttrDB
  :: TVar Glean.LatestRepos
  -> GleanDBName
  -> IO (Maybe (Glean.Repo, GleanDBAttrName))
getLatestAttrDB allRepos gleanDBName = case firstAttrDB gleanDBName of
  Nothing -> return Nothing
  Just attrDBName -> do
    dbs <- lookupLatestRepos allRepos [gleanAttrDBName attrDBName]
    return $ case dbs of
      [] -> Nothing
      db:_ -> Just (snd db, attrDBName)

withLog
  :: (LogRequest req, LogError req, LogResult res)
  => Text
  -> Glass.Env
  -> req
  -> (GleanGlassLogger -> IO (res, GleanGlassLogger, Maybe ErrorLogger))
  -> IO res
withLog cmd env req action = do
  fst <$> loggingAction
    (runLog env cmd)
    logResult
    (do
      (res, log, merr) <- action $ logRequest req
      forM_ merr $ \e -> runErrorLog env cmd (e <> logError req)
      return (res, log))

-- | Wrapper to enable perf logging, log the db names, and stats for
-- intermediate steps, and internal errors.
withLogDB
  :: (LogRequest req, LogError req, LogError dbs, LogRepo dbs, LogResult res)
  => Text
  -> Glass.Env
  -> req
  -> IO dbs
  -> Maybe Language
  -> (dbs -> Maybe Language -> IO (res, Maybe ErrorLogger))
  -> IO res
withLogDB cmd env req fetch mlanguage run =
  withLog cmd env req $ \log -> do
    db <- fetch
    (res,merr) <- run db mlanguage
    let err = fmap (<> logError db) merr
    return (res, log <> logRepo db, err)

-- | Run an action that provides a repo and maybe a language, log it
withRepoLanguage
  :: (LogError a, LogRequest a, LogResult b)
  => Text
  -> Glass.Env
  -> a
  -> RepoName
  -> Maybe Language
  -> (  NonEmpty (GleanDBName,Glean.Repo)
     -> Maybe Language
     -> IO (b, Maybe ErrorLogger))
  -> IO b
withRepoLanguage method env@Glass.Env{..} req repo mlanguage fn = do
  withLogDB method env req
    (getGleanRepos latestGleanRepos repo mlanguage)
    mlanguage
    fn

-- | Run an action that provides a repo and filepath, log it
withRepoFile :: (LogError a, LogRequest a, LogResult b) => Text
  -> Glass.Env
  -> a
  -> RepoName
  -> Path
  -> (  NonEmpty (GleanDBName,Glean.Repo)
     -> Maybe Language
     -> IO (b, Maybe ErrorLogger))
  -> IO b
withRepoFile method env req repo file fn = do
  withRepoLanguage method env req repo (filetype file) fn

-- | Run an action that provides a symbol id, log it
withSymbol
  :: LogResult c
  => Text
  -> Glass.Env
  -> SymbolId
  -> ((NonEmpty (GleanDBName, Glean.Repo), (RepoName, Language, [Text]))
  -> IO (c, Maybe ErrorLogger))
  -> IO c
withSymbol method env@Glass.Env{..} sym fn =
  withLogDB method env sym
    (case symbolTokens sym of
      Left err -> throwM $ ServerException err
      Right req@(repo, lang, _toks) -> do
        dbs <- getGleanRepos latestGleanRepos repo (Just lang)
        return (dbs, req))
    Nothing
    (\db _mlang -> fn db)

runLog :: Glass.Env -> Text -> GleanGlassLogger -> IO ()
runLog env cmd log = Logger.runLog (Glass.logger env) $
  log <> Logger.setMethod cmd

runErrorLog :: Glass.Env -> Text -> GleanGlassErrorsLogger -> IO ()
runErrorLog env cmd err = ErrorsLogger.runLog (Glass.logger env) $
  err <> ErrorsLogger.setMethod cmd

-- | Return a description for an Entity.
describeEntity
  :: LocationRange
  -> Code.Entity
  -> SymbolId
  -> Maybe SymbolKind
  -> Glean.RepoHaxl u w SymbolDescription
describeEntity
    LocationRange{..} decl symbolDescription_sym symbolDescription_kind = do
  repo <- Glean.haxlRepo
  qname <- toQualifiedName decl
  symbolDescription_name <- case qname of
    Right a -> return a
    Left err -> throwM $ ServerException err
  let symbolDescription_location =
        SymbolPath { symbolPath_range = locationRange_range
                   , symbolPath_repository = locationRange_repository
                   , symbolPath_filepath = locationRange_filepath
                   }
  annotations <- getAnnotationsForEntity decl
  symbolDescription_annotations <- case annotations of
    Right anns -> return anns
    Left err -> throwM $ ServerException err
  comments <- getCommentsForEntity locationRange_repository decl
  symbolDescription_comments <- case comments of
    Right comments -> return comments
    Left err -> throwM $ ServerException err
  let symbolDescription_repo_hash = Glean.repo_hash repo
  let symbolDescription_visibility = Nothing
  return SymbolDescription{..}

-- | Returns entities based on a string needle and an Angle query. Shared
-- implementation between searchByName and searchByNamePrefix.
searchEntityByString
  :: Text
  -> (Query.SearchCase -> [Code.SymbolKind] -> Text
      -> Angle (Code.Entity, Code.Location, Maybe Code.SymbolKind))
  -> Glass.Env
  -> SearchByNameRequest
  -> RequestOptions
  -> IO SearchByNameResult
searchEntityByString method query env@Glass.Env{..} req opts = do
    repoLangs <- filterRepoLang repo lang
    joinResults <$> Async.mapConcurrently searchEntityByStringRepoLang repoLangs
  where
    searchEntityByStringRepoLang (repo, lang) =
      withRepoLanguage method env req repo (Just lang) $ \gleanDBs _mlang -> do
        backendRunHaxl GleanBackend{..} $ do
          resultsAndDescriptions <-
            searchReposWithLimit limit (query caes reqKinds localName) $
              \result@(entity, Code.Location{..}, kind) -> do
                loc <- locationRangeFromCodeLocation
                        repo location_file location_location
                symbol <- toSymbolId repo entity
                description <-
                  describeEntity loc entity symbol
                    (symbolKindToSymbolKind <$> kind)
                gleanRepo <- Glean.haxlRepo
                return ((gleanRepo, result), description)
          let (results, descriptions) = unzip resultsAndDescriptions
          let mDescriptions = if terse then [] else descriptions
          symbols <- if terse
            then
              mapM
                (\(gleanRepo, (entity, _, _)) ->
                  withRepo gleanRepo $ toSymbolId repo entity) results
            else return $ map symbolDescription_sym descriptions
          return (SearchByNameResult symbols mDescriptions, Nothing)
    localName = searchByNameRequest_name req
    context = searchByNameRequest_context req
    reqKinds = map symbolKindFromSymbolKind $
      Set.elems $ searchContext_kinds context
    caes = if searchByNameRequest_ignoreCase req
            then Query.Insensitive
            else Query.Sensitive
    repo = searchContext_repo_name context
    limit = fromIntegral <$> requestOptions_limit opts
    lang = searchContext_language context
    terse = not $ searchByNameRequest_detailedResults req
    takeLimit :: [a] -> [a]
    takeLimit = maybe id take limit
    joinResults res =
      SearchByNameResult
        (takeLimit $ searchByNameResult_symbols =<< res)
        (takeLimit $ searchByNameResult_symbolDetails =<< res)

partialSymbolTokens
  :: SymbolId
  -> (Either Text RepoName, Either (Maybe Text) Language, [Text])
partialSymbolTokens (SymbolId symid) =
  (repoName, language, fromMaybe [] partialSym)
  where
    tokens = Text.split (=='/') symid
    (partialRepoName, partialLang, partialSym) = case tokens of
      [] -> error "partialSymbolTokens: the impossible has happened"
      [f] -> (f, Nothing, Nothing)
      [f, s] -> (f, Just s, Nothing)
      (f:s:rest) -> (f, Just s, Just rest)

    repoName = case toRepoName partialRepoName of
                Just repoName -> Right repoName
                Nothing -> Left partialRepoName
    language = case (partialSym, fromShortCode =<< partialLang) of
                  (Just _, Just lang) -> Right lang
                  (Just _, Nothing) -> Left partialLang
                  _ -> Left partialLang

searchRelated
  :: Glass.Env
  -> SymbolId
  -> RequestOptions
  -> SearchRelatedRequest
  -> IO SearchRelatedResult
searchRelated env@Glass.Env{..} sym opt req = do
    withSymbol "searchRelated" env sym $ \(gleanDBs, (repo, lang, toks)) -> do
      backendRunHaxl GleanBackend {..} $ do
        (edges, err) <-
          searchRelatedSymbols
          limit
          (if searchRelatedRequest_recursive then Recursive else NotRecursive)
          searchRelatedRequest_relation
          searchRelatedRequest_relatedBy
          (repo, lang, toks)
        let
          result = SearchRelatedResult
            { searchRelatedResult_edges = edges
            }
        pure (result, err)
  where
    RequestOptions {..} = opt
    SearchRelatedRequest {..} = req
    limit = fromIntegral $ case requestOptions_limit of
      Just x | x < rELATED_SYMBOLS_MAX_LIMIT -> x
      _ -> rELATED_SYMBOLS_MAX_LIMIT

-- Processing indexing requests
index :: Glass.Env -> IndexRequest -> IO IndexResponse
index env r = withIndexingService env $ IndexingService.index r

withIndexingService
  :: Glass.Env
  -> Thrift GleanIndexingService a
  -> IO a
withIndexingService env act =
  case mThriftBackend of
    Nothing -> err "no remote service connection available"
    Just (ThriftBackend config evb _ _) -> do
      let service :: ThriftService GleanIndexingService
          service = thriftServiceWithTimeout config opts
          onErr e = err $ "glean error: " <> Text.pack (show e)
      runThrift evb service act `catchAll` onErr
  where
    Glass.IndexBackend mThriftBackend = Glass.gleanIndexBackend env
    opts = ThriftServiceOptions $ Just timeout
    err e = throwIO $ ServerException e
    timeout = 60 -- seconds
