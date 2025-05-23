## Models for the Agent Communication Protocol
##
## This module contains the data models used in the Agent Communication Protocol,
## including Message, MessagePart, Run, and related types.

import std/[options, tables, json, times, random]
import jsony

type
  ContentType* = enum
    ctTextPlain = "text/plain"
    ctApplicationJson = "application/json"
    ctImageJpeg = "image/jpeg"
    ctImagePng = "image/png"
    ctCustom = "custom"

  ContentEncoding* = enum
    cePlain = "plain"
    ceBase64 = "base64"
    ceCustom = "custom"

  MessagePartObj* = object
    name*: Option[string]
    contentType*: ContentType
    content*: string
    contentEncoding*: ContentEncoding
    contentUrl*: Option[string]

  MessageObj* = object
    parts*: seq[MessagePartObj]

  RunStatus* = enum
    rsCreated = "created"
    rsRunning = "running"
    rsCompleted = "completed"
    rsAwaitingInput = "awaiting_input" 
    rsCancelled = "cancelled"
    rsError = "error"

  AgentDetail* = object
    name*: string
    description*: string
    metadata*: Table[string, JsonNode]

  AwaitRequest* = object
    prompt*: string
    timeout*: Option[int]
    inputSchema*: Option[JsonNode]

  RunObj* = object
    runId*: string
    agentName*: string
    sessionId*: string
    status*: RunStatus
    awaitRequest*: Option[AwaitRequest]
    output*: seq[MessageObj]
    error*: Option[string]
    createdAt*: DateTime
    updatedAt*: DateTime

# Constructor functions
proc newMessagePart*(content: string, contentType: ContentType = ctTextPlain, 
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

proc newMessage*(parts: seq[MessagePartObj]): MessageObj =
  result = MessageObj(parts: parts)

proc newTextMessage*(text: string): MessageObj =
  let part = newMessagePart(content = text, contentType = ctTextPlain)
  result = MessageObj(parts: @[part])

proc newJsonMessage*(data: JsonNode): MessageObj =
  let part = newMessagePart(
    content = $data, 
    contentType = ctApplicationJson
  )
  result = MessageObj(parts: @[part])

proc newAgentDetail*(name, description: string, 
                    metadata: Table[string, JsonNode] = initTable[string, JsonNode]()): AgentDetail =
  result = AgentDetail(
    name: name,
    description: description,
    metadata: metadata
  )

# Generate a pseudo-random ID (basic implementation for test compatibility)
proc generateId(): string =
  let timestamp = now().toTime().toUnix()
  result = $timestamp & "-" & $rand(100000)

proc newRun*(agentName: string, sessionId: string = "", 
            status: RunStatus = rsCreated): RunObj =
  let now = now()
  let sid = if sessionId == "": generateId() else: sessionId
  result = RunObj(
    runId: generateId(),
    agentName: agentName,
    sessionId: sid,
    status: status,
    awaitRequest: none(AwaitRequest),
    output: @[],
    error: none(string),
    createdAt: now,
    updatedAt: now
  )

# Helper methods for MessageObj
proc getText*(m: MessageObj): string =
  ## Get the text content from the first text/plain message part
  for part in m.parts:
    if part.contentType == ctTextPlain:
      return part.content
  return ""

proc getJson*(m: MessageObj): JsonNode =
  ## Get the JSON content from the first application/json message part
  for part in m.parts:
    if part.contentType == ctApplicationJson:
      return parseJson(part.content)
  return newJObject()

# JSON serialization/deserialization
proc fromJson*(T: typedesc[ContentType], jsonString: string): ContentType =
  case jsonString:
  of "text/plain": ctTextPlain
  of "application/json": ctApplicationJson
  of "image/jpeg": ctImageJpeg
  of "image/png": ctImagePng
  else: ctCustom

proc toJson*(value: ContentType): string =
  case value:
  of ctTextPlain: "\"text/plain\""
  of ctApplicationJson: "\"application/json\""
  of ctImageJpeg: "\"image/jpeg\""
  of ctImagePng: "\"image/png\""
  of ctCustom: "\"custom\""

proc fromJson*(T: typedesc[ContentEncoding], jsonString: string): ContentEncoding =
  case jsonString:
  of "plain": cePlain
  of "base64": ceBase64
  else: ceCustom

proc toJson*(value: ContentEncoding): string =
  case value:
  of cePlain: "\"plain\""
  of ceBase64: "\"base64\""
  of ceCustom: "\"custom\""

proc fromJson*(T: typedesc[RunStatus], jsonString: string): RunStatus =
  case jsonString:
  of "created": rsCreated
  of "running": rsRunning
  of "completed": rsCompleted
  of "awaiting_input": rsAwaitingInput
  of "cancelled": rsCancelled
  of "error": rsError
  else: rsError

proc toJson*(value: RunStatus): string =
  case value:
  of rsCreated: "\"created\""
  of rsRunning: "\"running\""
  of rsCompleted: "\"completed\""
  of rsAwaitingInput: "\"awaiting_input\""
  of rsCancelled: "\"cancelled\""
  of rsError: "\"error\""