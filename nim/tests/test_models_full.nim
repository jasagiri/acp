## Complete test coverage for models module
import unittest, options, tables, json, times
import ../src/acp/models

suite "ACP Models Complete Tests":
  test "ContentType enum and conversion":
    check ctTextPlain.toJson() == "\"text/plain\""
    check ctApplicationJson.toJson() == "\"application/json\""
    check ctImageJpeg.toJson() == "\"image/jpeg\""
    check ctImagePng.toJson() == "\"image/png\""
    check ctCustom.toJson() == "\"custom\""
    
    check ContentType.fromJson("text/plain") == ctTextPlain
    check ContentType.fromJson("application/json") == ctApplicationJson
    check ContentType.fromJson("image/jpeg") == ctImageJpeg
    check ContentType.fromJson("image/png") == ctImagePng
    check ContentType.fromJson("unknown") == ctCustom
  
  test "ContentEncoding enum and conversion":
    check cePlain.toJson() == "\"plain\""
    check ceBase64.toJson() == "\"base64\""
    check ceCustom.toJson() == "\"custom\""
    
    check ContentEncoding.fromJson("plain") == cePlain
    check ContentEncoding.fromJson("base64") == ceBase64
    check ContentEncoding.fromJson("unknown") == ceCustom
  
  test "RunStatus enum and conversion":
    check rsCreated.toJson() == "\"created\""
    check rsRunning.toJson() == "\"running\""
    check rsCompleted.toJson() == "\"completed\""
    check rsAwaitingInput.toJson() == "\"awaiting_input\""
    check rsCancelled.toJson() == "\"cancelled\""
    check rsError.toJson() == "\"error\""
    
    check RunStatus.fromJson("created") == rsCreated
    check RunStatus.fromJson("running") == rsRunning
    check RunStatus.fromJson("completed") == rsCompleted
    check RunStatus.fromJson("awaiting_input") == rsAwaitingInput
    check RunStatus.fromJson("cancelled") == rsCancelled
    check RunStatus.fromJson("error") == rsError
    check RunStatus.fromJson("unknown") == rsError
  
  test "MessagePart creation with all parameters":
    let part = newMessagePart(
      content = "Test content",
      contentType = ctApplicationJson,
      name = some("test-part"),
      contentEncoding = ceBase64,
      contentUrl = some("https://example.com/content")
    )
    
    check part.content == "Test content"
    check part.contentType == ctApplicationJson
    check part.name.get() == "test-part"
    check part.contentEncoding == ceBase64
    check part.contentUrl.get() == "https://example.com/content"
  
  test "MessagePart creation with defaults":
    let part = newMessagePart(content = "Default content")
    
    check part.content == "Default content"
    check part.contentType == ctTextPlain
    check part.name.isNone()
    check part.contentEncoding == cePlain
    check part.contentUrl.isNone()
  
  test "Message creation with parts":
    let part1 = newMessagePart(content = "First part")
    let part2 = newMessagePart(
      content = "{\"key\": \"value\"}",
      contentType = ctApplicationJson
    )
    
    let msg = newMessage(@[part1, part2])
    
    check msg.parts.len == 2
    check msg.parts[0].content == "First part"
    check msg.parts[1].contentType == ctApplicationJson
  
  test "Text message creation":
    let msg = newTextMessage("Simple text message")
    
    check msg.parts.len == 1
    check msg.parts[0].content == "Simple text message"
    check msg.parts[0].contentType == ctTextPlain
    check msg.getText() == "Simple text message"
  
  test "JSON message creation":
    let data = %*{"name": "test", "count": 42}
    let msg = newJsonMessage(data)
    
    check msg.parts.len == 1
    check msg.parts[0].contentType == ctApplicationJson
    
    let jsonData = msg.getJson()
    check jsonData["name"].getStr() == "test"
    check jsonData["count"].getInt() == 42
  
  test "AgentDetail creation":
    var metadata = initTable[string, JsonNode]()
    metadata["version"] = %"1.0.0"
    metadata["capabilities"] = %["text", "json"]
    
    let agent = newAgentDetail(
      name = "test-agent",
      description = "A test agent",
      metadata = metadata
    )
    
    check agent.name == "test-agent"
    check agent.description == "A test agent"
    check agent.metadata["version"].getStr() == "1.0.0"
    check agent.metadata["capabilities"].getElems().len == 2
  
  test "Run creation with defaults":
    let run = newRun(agentName = "test-agent")
    
    check run.agentName == "test-agent"
    check run.status == rsCreated
    check run.output.len == 0
    check run.error.isNone()
    check run.awaitRequest.isNone()
    check run.runId.len > 0
    check run.sessionId.len > 0
  
  test "Run creation with custom session ID":
    let sessionId = "custom-session-123"
    let run = newRun(
      agentName = "test-agent",
      sessionId = sessionId,
      status = rsRunning
    )
    
    check run.agentName == "test-agent"
    check run.sessionId == sessionId
    check run.status == rsRunning
  
  test "Message getText with multiple parts":
    let part1 = newMessagePart(
      content = "{\"key\": \"value\"}",
      contentType = ctApplicationJson
    )
    let part2 = newMessagePart(
      content = "Text content",
      contentType = ctTextPlain
    )
    
    let msg = newMessage(@[part1, part2])
    
    # Should return the first text/plain part
    check msg.getText() == "Text content"
  
  test "Message getText with no text parts":
    let part = newMessagePart(
      content = "{\"key\": \"value\"}",
      contentType = ctApplicationJson
    )
    
    let msg = newMessage(@[part])
    
    # Should return empty string if no text/plain parts
    check msg.getText() == ""
  
  test "Message getJson with no JSON parts":
    let part = newMessagePart(
      content = "Text content",
      contentType = ctTextPlain
    )
    
    let msg = newMessage(@[part])
    
    # Should return empty object if no application/json parts
    let jsonData = msg.getJson()
    check jsonData.kind == JObject
    check jsonData.getFields().len == 0

when isMainModule:
  echo "Running complete tests for ACP models..."