/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

include "glean/github/if/fb303.thrift"
include "glean/if/index.thrift"

namespace hs Glean
namespace hack GleanGlass
namespace py3 glean
namespace cpp2 glean

// request types

// Repositories are referred to by their SCS repo names
typedef string RepoName (hs.newtype)

// The UTF-8 path of a file relative to the source control root
typedef string Path (hs.newtype)

// Unique revision identifier (repo-wide unique id)
typedef string Revision (hs.newtype)

// A line range in the file to restrict the query. start should be <= end, and
// range is inclusive of end.
struct LineRange {
  // 1-based line index
  1: i64 lineBegin (hs.strict);

  // end line index, range is inclusive
  2: i64 lineEnd (hs.strict);
}

// Resolved symbol range in a file, using line/column locators.
// lines and columns are 1-indexed.
struct Range {
  1: i64 lineBegin (hs.strict);
  2: i64 columnBegin (hs.strict);
  3: i64 lineEnd (hs.strict);
  4: i64 columnEnd (hs.strict);
}

// Accurate byte ranges of symbols (can be resolved to Ranges)
struct ByteSpan {
  1: i64 start (hs.strict);
  2: i64 length (hs.strict);
}

// An universal, unresolved symbol location.
struct Location {
  // The repository it is defined in
  1: RepoName repository;

  // the filepath in that repository
  2: Path filepath;

  // unresolved bytespan location in file
  3: ByteSpan span (hs.strict);
}

// An universal, resolved symbol location.
struct LocationRange {
  // The repository it is defined in
  1: RepoName repository;

  // the filepath in that repository
  2: Path filepath;

  // resolved line/column ranges in file
  3: Range range (hs.strict);
}

// Generic request options, supported by most calls
struct RequestOptions {
  // repo-global revision identifier, otherwise latest index
  1: optional Revision revision;

  // maximum results to return.
  2: optional i32 limit;
}

// List symbols in a file. Symbols are spans of one or more tokens Glean has
// information on (e.g. references, declarations, ..)
struct DocumentSymbolsRequest {
  // SCS repo name (n.b not old style arcanist)
  1: RepoName repository;

  // UTF-8 path to file in repo relative to source control repo root
  2: Path filepath;

  // Limit results to this line range in file
  3: optional list<LineRange> range;

  // include references?
  4: bool include_refs = true;
}

// response types

// Human-readable opaque, stable, globally unique symbol identifier
typedef string SymbolId (hs.newtype)

// Type of attributes associated with a symbol.
union Attribute {
  1: bool aBool;
  2: i64 aInteger;
  3: double aDouble;
  4: string aString;
  5: list<string> aList;
}

// Symbol attributes, keyed by attribute name
typedef map<string, Attribute> Attributes (hs.newtype)

// For clients that can't process maps, use an assoc list for attributes
struct KeyedAttribute {
  1: string key;
  2: Attribute attribute;
}

// For clients that can't process maps, use an assoc list for attributes
typedef list<KeyedAttribute> AttributeList (hs.newtype)

// Reference symbols. These are use sites that point to their definition
struct ReferenceRangeSymbolX {
  // a symbol id to its definition
  1: SymbolId sym;

  // local line:col spans in this file
  2: Range range (hs.strict);

  // this points to the (unresolved) definition site
  3: LocationRange target;

  // attributes of this reference
  4: AttributeList attributes;

  // this points to an optional name range of the `target` rather than
  // the full definition. the range is assumed to be in the same
  // `repository` and `filepath` as the `target` field.
  5: optional Range targetName;
}

// a definition symbol
struct DefinitionSymbolX {
  // a stable name for the definition
  1: SymbolId sym;

  // the resolved local line:col spans in this file
  2: Range range (hs.strict);

  // attributes of this definition
  3: AttributeList attributes;

  // the resolved local line:col spans of the symbol name in this file
  4: optional Range nameRange (hs.strict);
}

// sometimes we prefer to combine all symbols in a file, for use later
struct SymbolX {
  // A stable name for the definition of this symbol
  1: SymbolId sym;

  // the resolved local line:col spans in this file
  2: Range range (hs.strict);

  // if this is a reference, it will point to its definition
  3: optional LocationRange target;

  // additional metadata associated with the symbol
  4: Attributes attributes;

  // the resolved local line:col spans of the symbol name in this file
  5: optional Range nameRange (hs.strict);

  // if this is a reference, it will point to the name of its definition
  6: optional Range targetName;
}

// Path-based symbol identifer. This is less stable than an SymbolId, and is
// stable only for a given revision. However, it is precise and efficient, in
// that it will uniquely map to an entity in the underlying database, without
// requiring search.
//
// (dons: how is this different to LocationRange?)
//
struct SymbolPath {
  // The repository it is defined in
  1: RepoName repository;

  // the filepath in that repository
  2: Path filepath;

  // the resolved local line:col spans in this file
  3: Range range (hs.strict);
}

// A list of known symbols in the file, their locations, and their keys
// with all locations resolved to line/column ranges, and attributes
struct DocumentSymbolListXResult {
  // references that appear in this file
  1: list<ReferenceRangeSymbolX> references;

  // definitions in this file
  2: list<DefinitionSymbolX> definitions;

  // actual revision used for results
  3: Revision revision;
}

// For cursor navigation in a file, it is useful to have a line indexed
// map of symbols (to quickly find token under cursor)
struct DocumentSymbolIndex {
  // all symbols present in this file, 1-indexed by line.
  1: map<i64, list<SymbolX>> symbols;

  // actual revision used for results
  2: Revision revision;

  // count of unique symbols in the map
  3: i64 size (hs.strict);
}

// Generic server exception
exception ServerException {
  1: string message;
}

// Type of abstract identifiers
typedef string Name (hs.newtype)

// A pair of names, usually a scope or qualified name and local identifier
struct QualifiedName {
  1: Name localName;
  2: Name container;
}

// Annotations/Attributes/Decorators/Directives attach metadata to definitions in source code
struct Annotation {
  1: string source; // the annotation as it appears in the source code
  2: optional SymbolId symbol; // the symbol of the annotation
  3: string name;
}

enum Visibility {
  Public = 20,
  Protected = 30,
  Private = 40,
}

// A symbol description extends the symbol id with additional attributes
struct SymbolDescription {
  1: SymbolId sym;
  2: SymbolPath location;
  3: QualifiedName name;
  4: optional SymbolKind kind;
  5: optional list<Annotation> annotations;
  6: list<LocationRange> comments;
  7: optional Visibility visibility;
  8: string repo_hash;
}

struct SearchContext {
  1: optional RepoName repo_name;
  2: optional Language language;
  4: set<SymbolKind> kinds;
}

// tags for symbol kinds, so clients can distinguish them
enum SymbolKind {
  Package = 1,
  Type = 2,
  Value = 3,
  File = 4,
  Module = 5,
  Namespace = 6,
  Class_ = 7,
  Method = 8,
  Property = 9,
  Field = 10,
  Constructor = 11,
  Enum = 12,
  Interface = 13,
  Function = 14,
  Variable = 15,
  Constant = 16,
  String = 17,
  Number = 18,
  Boolean = 19,
  Array = 20,
  Object = 21,
  Key = 22,
  Null = 23,
  Enumerator = 24,
  Struct = 25,
  Event = 26,
  Operator = 27,
  TypeParameter = 28,
  Union = 29,
  Macro = 30,
  Trait = 31,
} (
  hack.attributes = "\GraphQLEnum('GlassSymbolKind'), \RelayFlowEnum, \SelfDescriptive, \Oncalls('code_indexing')",
)

enum Language {
  Cpp = 1,
  JavaScript = 2,
  Hack = 3,
  Haskell = 4,
  Java = 5,
  ObjectiveC = 6,
  Python = 7,
  PreProcessor = 8,
  Thrift = 9,
  Rust = 10,
  Buck = 11,
  Erlang = 12,
} (
  hack.attributes = "\GraphQLEnum('GlassLanguage'), \RelayFlowEnum, \SelfDescriptive, \Oncalls('code_indexing')",
)

// Kinds of definitions. E.g. for jump-to-declaration or jump-to-definition
enum DefinitionKind {
  Definition = 1,
  Declaration = 2,
} (
  hack.attributes = "\GraphQLEnum('GlassDefinitionKind'), \SelfDescriptive, \Oncalls('code_indexing')",
)

struct SearchByNameRequest {
  1: SearchContext context;
  2: string name;
  3: bool detailedResults; // fill out symbol_details in the response
  4: bool ignoreCase = false;
}

struct SearchByNameResult {
  1: list<SymbolId> symbols;
  2: list<SymbolDescription> symbolDetails;
}

struct SearchBySymbolIdResult {
  1: list<SymbolId> symbols;
}

enum RelationType {
  Extends = 1, // OOP inheritance
  Contains = 2, // Syntactically nested (usually)
}

enum RelationDirection {
  Parent = 1,
  Child = 2,
}

struct SearchRelatedRequest {
  1: RelationType relatedBy;
  2: RelationDirection relation;
  3: bool recursive; // Not just directly related entities
  4: optional set<SymbolKind> filter; //return only these symbols of these kinds
}

// Consider capping the number of symbols in a single angle query before increasing this number
const i32 RELATED_SYMBOLS_MAX_LIMIT = 100;

struct RelatedSymbols {
  1: SymbolId parent;
  2: SymbolId child;
}

struct SearchRelatedResult {
  1: list<RelatedSymbols> edges;
}

// Glass symbol service
service GlassService extends fb303.FacebookService {
  // Return a list of symbols in the given file, with attributes
  DocumentSymbolListXResult documentSymbolListX(
    1: DocumentSymbolsRequest request,
    2: RequestOptions options,
  ) throws (1: ServerException e);

  // Return a line-index map of resolved symbols, useful for cursor lookup
  DocumentSymbolIndex documentSymbolIndex(
    1: DocumentSymbolsRequest request,
    2: RequestOptions options,
  ) throws (1: ServerException e);

  // Resolve a location span to a concrete line:col range in a file
  Range jumpTo(1: Location reference, 2: RequestOptions options) throws (
    1: ServerException e,
  );

  // Find any uses of a definition, generically
  list<Location> findReferences(
    1: SymbolId symbol,
    2: RequestOptions options,
  ) throws (1: ServerException e);

  // Find any uses of a definition, resolving all locations to line/col ranges
  list<LocationRange> findReferenceRanges(
    1: SymbolId symbol,
    2: RequestOptions options,
  ) throws (1: ServerException e);

  // Resolve a symbol id to its definition location
  Location resolveSymbol(1: SymbolId symbol, 2: RequestOptions options) throws (
    1: ServerException e,
  );

  // Return basic details about a symbol, a bit more than resolveSymbol
  SymbolDescription describeSymbol(
    1: SymbolId symbol,
    2: RequestOptions options,
  ) throws (1: ServerException e);

  // Find symbol ids based on exact local name
  // (e.g. Glean)
  SearchByNameResult searchByName(
    1: SearchByNameRequest request,
    3: RequestOptions options,
  ) throws (1: ServerException e);

  // Find symbol ids based on local name prefix
  // (e.g. Glea)
  SearchByNameResult searchByNamePrefix(
    1: SearchByNameRequest request,
    2: RequestOptions options,
  ) throws (1: ServerException e);

  // Find symbol ids based on the prefix of a full symbol id
  // (e.g. www/php/Gl)
  SearchBySymbolIdResult searchBySymbolId(
    1: SymbolId symbol_prefix,
    2: RequestOptions options,
  ) throws (1: ServerException e);

  SearchRelatedResult searchRelated(
    1: SymbolId symbol,
    2: RequestOptions options,
    3: SearchRelatedRequest request,
  ) throws (1: ServerException e);

  // Trigger the creation of an incremental database based on file changes
  // relative to an indexed revision
  index.IndexResponse index(1: index.IndexRequest request) throws (
    1: ServerException e,
  );
}
