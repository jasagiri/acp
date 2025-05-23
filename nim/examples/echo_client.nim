## Echo Client Example
##
## A simple client that interacts with an echo agent.

import std/[asyncdispatch, json]
import ../src/acp

proc main() {.async.} =
  # Create a new client
  let client = newClient("http://localhost:8000")
  
  try:
    # List available agents
    echo "Available agents:"
    let agents = await client.listAgents()
    for agent in agents:
      echo "  - ", agent.name, ": ", agent.description
    
    # Create a simple text message
    let message = newTextMessage("Hello from Nim ACP client!")
    
    # Run the echo agent with the message
    echo "\nRunning echo agent synchronously..."
    let run = await client.runSync("echo", @[message])
    
    echo "Run ID: ", run.runId
    echo "Status: ", run.status
    
    # Display the output
    echo "Output:"
    for msg in run.output:
      echo "  Message with ", msg.parts.len, " parts:"
      for part in msg.parts:
        echo "    - [", part.contentType, "] ", part.content
    
    # Try streaming with the streaming echo agent
    echo "\nRunning echo_stream agent with streaming..."
    
    # Define a handler for streaming events
    proc handleEvent(data: JsonNode) =
      if data.hasKey("thought"):
        echo "Agent thought: ", data["thought"].getStr()
      elif data.hasKey("message"):
        echo "Agent message: ", data["message"]
      else:
        echo "Event: ", data
    
    # Run with streaming
    let streamRun = await client.runStream(
      "echo_stream", 
      @[newTextMessage("This is a streaming message!")],
      onEvent = handleEvent
    )
    
    echo "Stream completed with status: ", streamRun.status
  
  finally:
    # Close the client
    await client.close()

# Run the main procedure
when isMainModule:
  waitFor main()