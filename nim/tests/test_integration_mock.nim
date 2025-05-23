## Mock integration tests for ACP SDK
import unittest, asyncdispatch, json, tables, options
import ../src/acp/models

# Mock types for integration testing
type
  Context* = ref object
    sessionId*: string
    runId*: string
    metadata*: Table[string, JsonNode]

  # Server components
  AgentFunc* = proc(input: seq[MessageObj], context: Context): Future[seq[MessageObj]] {.async.}
  Agent* = ref object
    name*: string
    description*: string
    fn*: AgentFunc
  
  Server* = ref object
    agents*: Table[string, Agent]
  
  # Client components
  Client* = ref object
    baseUrl*: string
    server*: Server  # Direct reference for mocking
  
  # Run components
  Run* = object
    runId*: string
    agentName*: string
    sessionId*: string
    status*: RunStatus
    output*: seq[MessageObj]
    error*: Option[string]

# Mock server implementation
proc newServer(): Server =
  result = Server(agents: initTable[string, Agent]())

proc registerAgent(server: Server, name, description: string, fn: AgentFunc) =
  let agent = Agent(
    name: name,
    description: description,
    fn: fn
  )
  server.agents[name] = agent

# Mock client implementation
proc newClient(server: Server, baseUrl: string = "http://localhost:8000"): Client =
  result = Client(
    baseUrl: baseUrl,
    server: server
  )

proc listAgents(client: Client): Future[seq[AgentDetail]] {.async.} =
  var agents: seq[AgentDetail] = @[]
  for name, agent in client.server.agents:
    agents.add(AgentDetail(
      name: agent.name,
      description: agent.description,
      metadata: initTable[string, JsonNode]()
    ))
  return agents

proc runSync(client: Client, agentName: string, 
            input: seq[MessageObj],
            sessionId: string = ""): Future[Run] {.async.} =
  if not client.server.agents.hasKey(agentName):
    raise newException(Exception, "Agent not found: " & agentName)
  
  let agent = client.server.agents[agentName]
  let sid = if sessionId == "": "session-" & $rand(1000) else: sessionId
  let context = Context(
    sessionId: sid,
    runId: "run-" & $rand(1000),
    metadata: initTable[string, JsonNode]()
  )
  
  let output = await agent.fn(input, context)
  
  result = Run(
    runId: context.runId,
    agentName: agentName,
    sessionId: context.sessionId,
    status: rsCompleted,
    output: output,
    error: none(string)
  )

# Test agent implementations
proc echoAgent(input: seq[MessageObj], context: Context): Future[seq[MessageObj]] {.async.} =
  return input

proc reverseAgent(input: seq[MessageObj], context: Context): Future[seq[MessageObj]] {.async.} =
  var output: seq[MessageObj] = @[]
  
  for msg in input:
    var parts: seq[MessagePartObj] = @[]
    
    for part in msg.parts:
      if part.contentType == ctTextPlain:
        # Reverse the text content
        let reversed = part.content.reversed
        parts.add(newMessagePart(
          content = reversed,
          contentType = ctTextPlain
        ))
      else:
        # Keep non-text parts as-is
        parts.add(part)
    
    output.add(newMessage(parts))
  
  return output

proc metadataAgent(input: seq[MessageObj], context: Context): Future[seq[MessageObj]] {.async.} =
  # Store metadata from input
  for msg in input:
    let text = msg.getText()
    if text.len > 0:
      context.metadata["last_input"] = %text
  
  # Create response with context information
  var parts: seq[MessagePartObj] = @[]
  parts.add(newMessagePart(
    content = "Session ID: " & context.sessionId & ", Run ID: " & context.runId,
    contentType = ctTextPlain
  ))
  
  return @[newMessage(parts)]

# Integration tests
suite "ACP Integration Tests":
  test "Echo agent round trip":
    proc testEchoIntegration() {.async.} =
      # Create server and register agents
      let server = newServer()
      server.registerAgent("echo", "Echo agent", echoAgent)
      
      # Create client connected to server
      let client = newClient(server)
      
      # Create test message
      let message = newTextMessage("Hello, echo agent!")
      
      # Run the agent
      let run = await client.runSync("echo", @[message])
      
      # Check results
      check run.agentName == "echo"
      check run.status == rsCompleted
      check run.output.len == 1
      check run.output[0].parts.len == 1
      check run.output[0].parts[0].content == "Hello, echo agent!"
    
    waitFor testEchoIntegration()
  
  test "Reverse agent transformation":
    proc testReverseIntegration() {.async.} =
      # Create server and register agents
      let server = newServer()
      server.registerAgent("reverse", "Reverses text", reverseAgent)
      
      # Create client connected to server
      let client = newClient(server)
      
      # Create test message
      let message = newTextMessage("Hello, world!")
      
      # Run the agent
      let run = await client.runSync("reverse", @[message])
      
      # Check results
      check run.agentName == "reverse"
      check run.status == rsCompleted
      check run.output.len == 1
      check run.output[0].parts.len == 1
      check run.output[0].parts[0].content == "!dlrow ,olleH"
    
    waitFor testReverseIntegration()
  
  test "Agent not found error":
    proc testAgentNotFound() {.async.} =
      # Create server with no agents
      let server = newServer()
      
      # Create client connected to server
      let client = newClient(server)
      
      # Create test message
      let message = newTextMessage("Hello!")
      
      # Running non-existent agent should fail
      var exceptionCaught = false
      try:
        discard await client.runSync("non-existent", @[message])
      except Exception:
        exceptionCaught = true
      
      check exceptionCaught == true
    
    waitFor testAgentNotFound()
  
  test "Context and metadata persistence":
    proc testContextPersistence() {.async.} =
      # Create server and register metadata agent
      let server = newServer()
      server.registerAgent("metadata", "Context metadata agent", metadataAgent)
      
      # Create client connected to server
      let client = newClient(server)
      
      # Create test message
      let message = newTextMessage("Store this metadata")
      
      # Run the agent with a fixed session ID
      let sessionId = "test-session-123"
      let run = await client.runSync("metadata", @[message], sessionId)
      
      # Check results
      check run.agentName == "metadata"
      check run.sessionId == sessionId
      check run.status == rsCompleted
      check run.output.len == 1
      check run.output[0].getText().contains(sessionId)
    
    waitFor testContextPersistence()
  
  test "Multiple agents through same client":
    proc testMultipleAgents() {.async.} =
      # Create server and register multiple agents
      let server = newServer()
      server.registerAgent("echo", "Echo agent", echoAgent)
      server.registerAgent("reverse", "Reverses text", reverseAgent)
      
      # Create client connected to server
      let client = newClient(server)
      
      # List available agents
      let agents = await client.listAgents()
      check agents.len == 2
      
      # Create test message
      let message = newTextMessage("Test message")
      
      # Run echo agent
      let echoRun = await client.runSync("echo", @[message])
      check echoRun.agentName == "echo"
      check echoRun.output[0].getText() == "Test message"
      
      # Run reverse agent
      let reverseRun = await client.runSync("reverse", @[message])
      check reverseRun.agentName == "reverse"
      check reverseRun.output[0].getText() == "egassem tseT"
    
    waitFor testMultipleAgents()

when isMainModule:
  echo "Running integration tests for ACP..."