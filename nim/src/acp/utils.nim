## Utility functions for the Agent Communication Protocol
##
## This module provides utility functions used by both server and client components.

import std/[json, options, tables, strutils, times]

# JSON helpers
proc getStr*(node: JsonNode, default: string = ""): string =
  if node.isNil or node.kind != JString:
    return default
  return node.getStr()

proc getInt*(node: JsonNode, default: int = 0): int =
  if node.isNil or node.kind != JInt:
    return default
  return node.getInt()

proc getBool*(node: JsonNode, default: bool = false): bool =
  if node.isNil or node.kind != JBool:
    return default
  return node.getBool()

proc toTable*(node: JsonNode): Table[string, JsonNode] =
  result = initTable[string, JsonNode]()
  if node.isNil or node.kind != JObject:
    return result
  
  for key, value in node.pairs:
    result[key] = value

# Cache implementation (basic TTL cache)
type
  CacheEntry[T] = object
    value: T
    expires: int64  # timestamp in milliseconds

  TTLCache*[K, V] = ref object
    data: Table[K, CacheEntry[V]]
    ttl: int  # milliseconds

proc newTTLCache*[K, V](ttl: int): TTLCache[K, V] =
  TTLCache[K, V](
    data: initTable[K, CacheEntry[V]](),
    ttl: ttl
  )

proc currentTimeMs(): int64 =
  return (getTime().toUnix() * 1000).int64

proc get*[K, V](cache: TTLCache[K, V], key: K): Option[V] =
  if not cache.data.hasKey(key):
    return none(V)
  
  let entry = cache.data[key]
  let now = currentTimeMs()
  
  if entry.expires < now:
    cache.data.del(key)
    return none(V)
  
  return some(entry.value)

proc put*[K, V](cache: TTLCache[K, V], key: K, value: V) =
  let expires = currentTimeMs() + cache.ttl.int64
  cache.data[key] = CacheEntry[V](value: value, expires: expires)

proc clear*[K, V](cache: TTLCache[K, V]) =
  cache.data.clear()

# String helpers
proc truncate*(s: string, maxLen: int): string =
  if s.len <= maxLen:
    return s
  return s[0..<maxLen] & "..."

# Debug helper
template debugLog*(verbosity: int, minLevel: int, msg: string) =
  if verbosity >= minLevel:
    echo msg