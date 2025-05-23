import unittest
import json
import ../src/acp/models

suite "ACP Models Basic Tests":
  test "MessagePart creation":
    let part = newMessagePart(
      content = "Hello, world!",
      contentType = ctTextPlain
    )
    
    check part.content == "Hello, world!"
    check part.contentType == ctTextPlain
    check part.contentEncoding == cePlain
  
  test "Message creation with text":
    let msg = newTextMessage("Hello, ACP!")
    
    check msg.parts.len == 1
    check msg.parts[0].content == "Hello, ACP!"
    check msg.parts[0].contentType == ctTextPlain
    
    # Test getText helper
    check msg.getText() == "Hello, ACP!"
  
  test "Message creation with JSON":
    let data = %*{"name": "test", "value": 42}
    let msg = newJsonMessage(data)
    
    check msg.parts.len == 1
    check msg.parts[0].contentType == ctApplicationJson
    
    # Test getJson helper
    let parsedJson = msg.getJson()
    check parsedJson["name"].getStr() == "test"
    check parsedJson["value"].getInt() == 42
  
  test "RunObj basic creation":
    let run = newRun(agentName = "test_agent")
    
    check run.status == rsCreated
    check run.agentName == "test_agent"