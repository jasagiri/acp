## Standalone test for ACP Nim models
## This test doesn't require external dependencies

import std/[unittest, json, options, tables, times]

# Simplified model definitions for testing
type
  ContentType = enum
    ctTextPlain = "text/plain"
    ctApplicationJson = "application/json"
    ctImageJpeg = "image/jpeg"
    ctImagePng = "image/png"
    ctCustom = "custom"

  ContentEncoding = enum
    cePlain = "plain"
    ceBase64 = "base64"
    ceCustom = "custom"

  MessagePartObj = object
    name: Option[string]
    contentType: ContentType
    content: string
    contentEncoding: ContentEncoding
    contentUrl: Option[string]

  MessageObj = object
    parts: seq[MessagePartObj]

# Constructor function
proc newMessagePart(content: string, contentType: ContentType = ctTextPlain, 
                   name: Option[string] = none(string), 
                   contentEncoding: ContentEncoding = cePlain,
                   contentUrl: Option[string] = none(string)): MessagePartObj =
  result = MessagePartObj(
    name: name,
    contentType: contentType,
    content: content,
    contentEncoding: contentEncoding,
    contentUrl: contentUrl
  )

proc newTextMessage(text: string): MessageObj =
  let part = newMessagePart(content = text, contentType = ctTextPlain)
  result = MessageObj(parts: @[part])

# Tests
suite "ACP Models Basic Tests":
  test "MessagePart creation":
    let part = newMessagePart(
      content = "Hello, world!",
      contentType = ctTextPlain
    )
    
    check part.content == "Hello, world!"
    check part.contentType == ctTextPlain
    check part.contentEncoding == cePlain
    check part.name.isNone()
    check part.contentUrl.isNone()
  
  test "Message creation with text":
    let msg = newTextMessage("Hello, ACP!")
    
    check msg.parts.len == 1
    check msg.parts[0].content == "Hello, ACP!"
    check msg.parts[0].contentType == ctTextPlain

when isMainModule:
  echo "Running standalone test for ACP Nim models..."
  echo "All tests completed!"