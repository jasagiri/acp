## Complete test coverage for utils module
import unittest, times, json, tables, options
from ../src/acp/utils as acpUtils import nil

suite "ACP Utils Complete Tests":
  test "getStr with valid JSON string":
    let node = %"test string"
    check acpUtils.getStr(node) == "test string"
  
  test "getStr with non-string JSON":
    let node = %42
    check getStr(node) == ""
  
  test "getStr with nil JSON":
    let node: JsonNode = nil
    check getStr(node) == ""
  
  test "getStr with default value":
    let node: JsonNode = nil
    check getStr(node, "default") == "default"
  
  test "getInt with valid JSON int":
    let node = %42
    check getInt(node) == 42
  
  test "getInt with non-int JSON":
    let node = %"not an int"
    check getInt(node) == 0
  
  test "getInt with nil JSON":
    let node: JsonNode = nil
    check getInt(node) == 0
  
  test "getInt with default value":
    let node: JsonNode = nil
    check getInt(node, 100) == 100
  
  test "getBool with valid JSON bool":
    let nodeTrue = %true
    let nodeFalse = %false
    check getBool(nodeTrue) == true
    check getBool(nodeFalse) == false
  
  test "getBool with non-bool JSON":
    let node = %"not a bool"
    check getBool(node) == false
  
  test "getBool with nil JSON":
    let node: JsonNode = nil
    check getBool(node) == false
  
  test "getBool with default value":
    let node: JsonNode = nil
    check getBool(node, true) == true
  
  test "toTable with valid JSON object":
    let node = %*{"key1": "value1", "key2": 42}
    let table = toTable(node)
    
    check table.len == 2
    check table["key1"].getStr() == "value1"
    check table["key2"].getInt() == 42
  
  test "toTable with non-object JSON":
    let node = %"not an object"
    let table = toTable(node)
    
    check table.len == 0
  
  test "toTable with nil JSON":
    let node: JsonNode = nil
    let table = toTable(node)
    
    check table.len == 0
  
  test "TTLCache get and put":
    let cache = newTTLCache[string, int](1000)  # 1 second TTL
    
    cache.put("key1", 42)
    check cache.get("key1").get() == 42
    check cache.get("non-existent").isNone()
  
  test "TTLCache expiration":
    let cache = newTTLCache[string, int](10)  # 10 milliseconds TTL
    
    cache.put("key1", 42)
    check cache.get("key1").get() == 42
    
    # Sleep to let cache entry expire
    sleep(20)
    
    check cache.get("key1").isNone()
  
  test "TTLCache clear":
    let cache = newTTLCache[string, int](1000)
    
    cache.put("key1", 42)
    cache.put("key2", 100)
    
    check cache.get("key1").get() == 42
    check cache.get("key2").get() == 100
    
    cache.clear()
    
    check cache.get("key1").isNone()
    check cache.get("key2").isNone()
  
  test "truncate string within limit":
    let str = "Short string"
    check truncate(str, 20) == str
  
  test "truncate string exceeding limit":
    let str = "This is a very long string that needs truncation"
    let result = truncate(str, 15)
    
    check result.len == 18  # 15 chars + "..."
    check result == "This is a very..."
  
  test "debugLog with sufficient verbosity":
    # This is mostly a compile-time test
    var output = ""
    template mockEcho(msg: string) =
      output = msg
    
    template echo(msg: string) =
      mockEcho(msg)
    
    debugLog(2, 1, "Test message")
    check output == "Test message"
  
  test "debugLog with insufficient verbosity":
    var output = ""
    template mockEcho(msg: string) =
      output = msg
    
    template echo(msg: string) =
      mockEcho(msg)
    
    debugLog(1, 2, "Test message")
    check output == ""  # Should not output anything

when isMainModule:
  echo "Running complete tests for ACP utils..."