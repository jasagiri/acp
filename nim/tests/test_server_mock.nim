## Test coverage for server module using mocks
import unittest, asyncdispatch, json, tables, options
import ../src/acp/models

# Mock types to test server functionality without dependencies
type
  Context* = ref object
    sessionId*: string
    runId*: string
    metadata*: Table[string, JsonNode]

  AgentFunc* = proc(input: seq[MessageObj], context: Context): Future[seq[MessageObj]] {.async.}
  StreamingAgentFunc* = proc(input: seq[MessageObj], context: Context, 
                            yieldFn: proc(data: JsonNode): Future[void] {.async.}): Future[seq[MessageObj]] {.async.}
  
  Agent* = ref object
    name*: string
    description*: string
    metadata*: Table[string, JsonNode]
    fn*: AgentFunc
    streamingFn*: StreamingAgentFunc
    supportsStreaming*: bool

  AgentRegistry* = Table[string, Agent]
  
  RunBundle* = ref object
    run*: RunObj
    input*: seq[MessageObj]
    context*: Context
    agent*: Agent
  
  Server* = ref object
    agents*: AgentRegistry
    settings*: object
      host*: string
      port*: int
      verbosity*: int

# Mock implementation of server functions
proc newServer(host: string = "127.0.0.1", port: int = 8000, verbosity: int = 0): Server =
  result = Server(
    agents: initTable[string, Agent](),
    settings: (host: host, port: port, verbosity: verbosity)
  )

proc registerAgent(server: Server, name, description: string, agentFn: AgentFunc, 
                 metadata: Table[string, JsonNode] = initTable[string, JsonNode]()): void =
  let agent = Agent(
    name: name,
    description: description,
    metadata: metadata,
    fn: agentFn,
    streamingFn: nil,
    supportsStreaming: false
  )
  server.agents[name] = agent

proc registerStreamingAgent(server: Server, name, description: string, 
                          streamingFn: StreamingAgentFunc,
                          metadata: Table[string, JsonNode] = initTable[string, JsonNode]()): void =
  let agent = Agent(
    name: name,
    description: description,
    metadata: metadata,
    fn: nil,
    streamingFn: streamingFn,
    supportsStreaming: true
  )
  server.agents[name] = agent

# Test agent functions
proc echoAgent(input: seq[MessageObj], context: Context): Future[seq[MessageObj]] {.async.} =
  return input

proc streamingEchoAgent(input: seq[MessageObj], context: Context, 
                      yieldFn: proc(data: JsonNode): Future[void] {.async.}): Future[seq[MessageObj]] {.async.} =
  await yieldFn(%*{"thought": "Echo thought"})
  return input

# Tests
suite "ACP Server Mocked Tests":
  test "Server initialization":
    let server = newServer(port = 9000, verbosity = 2)
    check server.settings.port == 9000
    check server.settings.host == "127.0.0.1"
    check server.settings.verbosity == 2
    check server.agents.len == 0
  
  test "Agent registration":
    let server = newServer()
    
    # Register a standard agent
    server.registerAgent(
      name = "echo",
      description = "Echo agent",
      agentFn = echoAgent
    )
    
    check server.agents.len == 1
    check server.agents.hasKey("echo")
    check server.agents["echo"].name == "echo"
    check server.agents["echo"].description == "Echo agent"
    check server.agents["echo"].supportsStreaming == false
    check not server.agents["echo"].fn.isNil
    check server.agents["echo"].streamingFn.isNil
  
  test "Streaming agent registration":
    let server = newServer()
    
    var metadata = initTable[string, JsonNode]()
    metadata["version"] = %"1.0"
    
    # Register a streaming agent
    server.registerStreamingAgent(
      name = "echo_stream",
      description = "Streaming echo agent",
      streamingFn = streamingEchoAgent,
      metadata = metadata
    )
    
    check server.agents.len == 1
    check server.agents.hasKey("echo_stream")
    check server.agents["echo_stream"].name == "echo_stream"
    check server.agents["echo_stream"].description == "Streaming echo agent"
    check server.agents["echo_stream"].supportsStreaming == true
    check server.agents["echo_stream"].fn.isNil
    check not server.agents["echo_stream"].streamingFn.isNil
    check server.agents["echo_stream"].metadata["version"].getStr() == "1.0"
  
  test "Multiple agent registration":
    let server = newServer()
    
    server.registerAgent("agent1", "First agent", echoAgent)
    server.registerAgent("agent2", "Second agent", echoAgent)
    server.registerStreamingAgent("agent3", "Third agent", streamingEchoAgent)
    
    check server.agents.len == 3
    check server.agents.hasKey("agent1")
    check server.agents.hasKey("agent2")
    check server.agents.hasKey("agent3")

# Test agent execution using the mock agent functions
suite "ACP Agent Execution Tests":
  test "Standard agent execution":
    proc testEchoAgent() {.async.} =
      # Create input message
      let msg = newTextMessage("Test message")
      let input = @[msg]
      
      # Create context
      let context = Context(
        sessionId: "test-session",
        runId: "test-run",
        metadata: initTable[string, JsonNode]()
      )
      
      # Execute agent
      let output = await echoAgent(input, context)
      
      check output.len == 1
      check output[0].parts.len == 1
      check output[0].parts[0].content == "Test message"
    
    waitFor testEchoAgent()
  
  test "Streaming agent execution":
    proc testStreamingAgent() {.async.} =
      # Create input message
      let msg = newTextMessage("Test streaming message")
      let input = @[msg]
      
      # Create context
      let context = Context(
        sessionId: "test-session",
        runId: "test-run",
        metadata: initTable[string, JsonNode]()
      )
      
      # Mock yield function to capture intermediate outputs
      var yieldedData: seq[JsonNode] = @[]
      proc mockYield(data: JsonNode): Future[void] {.async.} =
        yieldedData.add(data)
      
      # Execute streaming agent
      let output = await streamingEchoAgent(input, context, mockYield)
      
      # Check intermediate yields
      check yieldedData.len == 1
      check yieldedData[0]["thought"].getStr() == "Echo thought"
      
      # Check final output
      check output.len == 1
      check output[0].parts.len == 1
      check output[0].parts[0].content == "Test streaming message"
    
    waitFor testStreamingAgent()

when isMainModule:
  echo "Running tests for ACP server with mocks..."