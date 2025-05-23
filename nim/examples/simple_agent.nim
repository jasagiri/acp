## Simple Agent Example
##
## A minimal ACP agent with no external dependencies.

import std/[asyncdispatch, json, tables, options]

# Minimal model definitions
type
  ContentType = enum
    ctTextPlain = "text/plain"
    ctApplicationJson = "application/json"

  MessagePart = object
    content: string
    contentType: ContentType

  Message = object
    parts: seq[MessagePart]

  AgentContext = object
    sessionId: string
    runId: string
    metadata: Table[string, JsonNode]

# Simple agent function
proc simpleAgent(input: seq[Message], context: AgentContext): Future[seq[Message]] {.async.} =
  # Create a response message
  var responseParts: seq[MessagePart] = @[]
  
  # Append a text part
  responseParts.add(MessagePart(
    content: "Hello from Nim ACP agent!",
    contentType: ctTextPlain
  ))
  
  # Return the response
  return @[Message(parts: responseParts)]

# Main - simulate running the agent
proc main() {.async.} =
  echo "ACP Nim Agent Example"
  echo "====================="
  
  # Create a simple context
  let context = AgentContext(
    sessionId: "test-session",
    runId: "test-run",
    metadata: initTable[string, JsonNode]()
  )
  
  # Create a simple input
  let inputParts = @[MessagePart(
    content: "Hello, agent!",
    contentType: ctTextPlain
  )]
  let input = @[Message(parts: inputParts)]
  
  # Run the agent
  echo "Running agent..."
  let output = await simpleAgent(input, context)
  
  # Display the output
  echo "\nAgent response:"
  for msg in output:
    for part in msg.parts:
      echo "  [", part.contentType, "] ", part.content

# Run the simulation
when isMainModule:
  waitFor main()