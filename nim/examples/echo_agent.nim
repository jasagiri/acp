## Echo Agent Example
##
## A simple echo agent that returns any message it receives.

import std/[asyncdispatch, json]
import ../src/acp

# Create a new server
let server = newServer(port = 8000)

# Define our echo agent function
proc echoAgent(input: seq[MessageObj], context: Context): Future[seq[MessageObj]] {.async.} =
  # Simply return the input messages as output
  return input

# Register the agent with the server
server.registerAgent(
  name = "echo",
  description = "Echoes everything",
  agentFn = echoAgent
)

# Define a streaming version with thoughts
proc streamingEchoAgent(
  input: seq[MessageObj], 
  context: Context, 
  yieldFn: YieldFn
): Future[seq[MessageObj]] {.async.} =
  # Yield a thought first
  await yieldFn(%*{"thought": "I should echo everything"})
  
  # Add a small delay to simulate processing
  await sleepAsync(500)
  
  # Now yield each message
  for msg in input:
    await yieldFn(%*{"message": msg.toJson().parseJson()})
    await sleepAsync(200)
  
  # Return the complete set of messages
  return input

# Register the streaming agent
server.registerStreamingAgent(
  name = "echo_stream",
  description = "Echoes everything with streaming",
  streamingFn = streamingEchoAgent
)

# Start the server
echo "Starting ACP echo server on http://localhost:8000"
server.run()