## Server implementation for Agent Communication Protocol
##
## This module provides the server implementation for hosting ACP agents.

import std/[asyncdispatch, json, tables, options, sequtils, strformat, times, uuids, strutils]
import jester
import ./models
import ./utils

type
  Context* = ref object
    ## Context object for agent execution
    sessionId*: string
    runId*: string
    metadata*: Table[string, JsonNode]

  AgentFunc* = proc(input: seq[MessageObj], context: Context): Future[seq[MessageObj]] {.async.}
  YieldFn* = proc(data: JsonNode): Future[void] {.async.}
  
  StreamingAgentFunc* = proc(input: seq[MessageObj], context: Context, yieldFn: YieldFn): Future[seq[MessageObj]] {.async.}
  
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
    settings*: ServerSettings
  
  ServerSettings* = object
    host*: string
    port*: int
    verbosity*: int

# Initialize a new server
proc newServer*(host: string = "127.0.0.1", port: int = 8000, verbosity: int = 0): Server =
  result = Server(
    agents: initTable[string, Agent](),
    settings: ServerSettings(
      host: host,
      port: port,
      verbosity: verbosity
    )
  )

# Register a standard (non-streaming) agent
proc registerAgent*(server: Server, name, description: string, agentFn: AgentFunc, 
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

# Register a streaming agent
proc registerStreamingAgent*(server: Server, name, description: string, 
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

# Create macros for agent registration
template agent*(server: Server, name, description: string, 
              metadata: Table[string, JsonNode] = initTable[string, JsonNode]()): untyped =
  ## Decorator-style macro for registering an agent
  proc wrapAgent(agentFn: AgentFunc) =
    server.registerAgent(name, description, agentFn, metadata)
  wrapAgent

template streamingAgent*(server: Server, name, description: string,
                      metadata: Table[string, JsonNode] = initTable[string, JsonNode]()): untyped =
  ## Decorator-style macro for registering a streaming agent
  proc wrapStreamingAgent(streamingFn: StreamingAgentFunc) =
    server.registerStreamingAgent(name, description, streamingFn, metadata)
  wrapStreamingAgent

# Create a new run bundle
proc newRunBundle(agent: Agent, input: seq[MessageObj], sessionId: string = ""): RunBundle =
  let sid = if sessionId == "": $genUUID() else: sessionId
  let run = newRun(agent.name, sid)
  let context = Context(
    sessionId: sid,
    runId: run.runId,
    metadata: initTable[string, JsonNode]()
  )
  
  result = RunBundle(
    run: run,
    input: input,
    context: context,
    agent: agent
  )

# Execute a run
proc executeRun(bundle: RunBundle): Future[RunObj] {.async.} =
  var run = bundle.run
  run.status = rsRunning
  run.updatedAt = now()
  
  try:
    let output = await bundle.agent.fn(bundle.input, bundle.context)
    run.output = output
    run.status = rsCompleted
  except Exception as e:
    run.error = some(e.msg)
    run.status = rsError
  
  run.updatedAt = now()
  return run

# Execute a streaming run
proc executeStreamingRun(bundle: RunBundle, yieldFn: YieldFn): Future[RunObj] {.async.} =
  var run = bundle.run
  run.status = rsRunning
  run.updatedAt = now()
  var output: seq[MessageObj] = @[]
  
  try:
    output = await bundle.agent.streamingFn(bundle.input, bundle.context, yieldFn)
    run.output = output
    run.status = rsCompleted
  except Exception as e:
    run.error = some(e.msg)
    run.status = rsError
  
  run.updatedAt = now()
  return run

# Create HTTP routes
proc setupRoutes(server: Server): Router =
  let publicAgents = collect:
    for name, agent in server.agents.pairs:
      AgentDetail(
        name: agent.name,
        description: agent.description,
        metadata: agent.metadata
      )
  
  result = newRouter()
  
  # List agents endpoint
  result.get "/agents":
    resp Http200, %*{"agents": publicAgents}
  
  # Get specific agent details
  result.get "/agents/@name":
    let name = @"name"
    if not server.agents.hasKey(name):
      resp Http404, %*{"error": fmt"Agent '{name}' not found"}
    
    let agent = server.agents[name]
    resp Http200, %*{
      "name": agent.name,
      "description": agent.description,
      "metadata": agent.metadata
    }
  
  # Create a run
  result.post "/runs":
    var data: JsonNode
    try:
      data = parseJson(request.body)
    except:
      resp Http400, %*{"error": "Invalid JSON request body"}
      return
    
    let agentName = getStr(data{"agent_name"})
    if agentName == "" or not server.agents.hasKey(agentName):
      resp Http404, %*{"error": fmt"Agent '{agentName}' not found"}
      return
    
    let agent = server.agents[agentName]
    
    # Parse input messages
    var inputMsgs: seq[MessageObj] = @[]
    try:
      let inputJson = data{"input"}
      if not inputJson.isNil and inputJson.kind == JArray:
        inputMsgs = fromJson(seq[MessageObj], $inputJson)
    except Exception as e:
      resp Http400, %*{"error": fmt"Invalid input format: {e.msg}"}
      return
    
    let sessionId = getStr(data{"session_id"}, "")
    let stream = getBool(data{"stream"}, false)
    
    let bundle = newRunBundle(agent, inputMsgs, sessionId)
    
    if stream and agent.supportsStreaming:
      # Streaming response
      request.response.headers["Content-Type"] = "text/event-stream"
      request.response.headers["Cache-Control"] = "no-cache"
      request.response.headers["Connection"] = "keep-alive"
      
      await request.response.sendHeaders()
      
      proc yieldData(data: JsonNode): Future[void] {.async.} =
        let eventData = "data: " & $data & "\n\n"
        await request.response.send(eventData)
        await request.response.flushFile()
      
      # Execute the run with streaming
      var finalRun = await executeStreamingRun(bundle, yieldData)
      
      # Send final event
      let finalEvent = "data: " & $finalRun.toJson() & "\n\n"
      await request.response.send(finalEvent)
      await request.response.flushFile()
      request.response.finish()
    else:
      # Non-streaming response
      let run = await executeRun(bundle)
      resp Http200, toJson(run)
  
  # Get a run
  result.get "/runs/@runId":
    let runId = @"runId"
    # In a real implementation, you'd fetch the run from a database
    resp Http501, %*{"error": "Not implemented"}
  
  # Resume a run
  result.post "/runs/@runId/resume":
    let runId = @"runId"
    # In a real implementation, you'd fetch and resume the run
    resp Http501, %*{"error": "Not implemented"}
  
  # Cancel a run
  result.post "/runs/@runId/cancel":
    let runId = @"runId"
    # In a real implementation, you'd fetch and cancel the run
    resp Http501, %*{"error": "Not implemented"}

# Run the server
proc run*(server: Server) =
  let router = setupRoutes(server)
  let settings = server.settings
  
  let port = Port(settings.port)
  var jesterSettings = newSettings()
  jesterSettings.port = port
  jesterSettings.bindAddr = settings.host
  
  var jester = initJester(router, jesterSettings)
  jester.serve()