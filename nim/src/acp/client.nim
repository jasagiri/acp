## Client implementation for Agent Communication Protocol
##
## This module provides the client implementation for consuming ACP agents.

import std/[asyncdispatch, json, tables, options, strformat, httpclient, uri]
import jsony
import ./models
import ./utils

type
  ClientSettings* = object
    baseUrl*: string
    timeout*: int  # Timeout in milliseconds

  Client* = ref object
    settings*: ClientSettings
    httpClient*: AsyncHttpClient

# Create a new client
proc newClient*(baseUrl: string, timeout: int = 30000): Client =
  let httpClient = newAsyncHttpClient(
    timeout = timeout,
    headers = newHttpHeaders({"Content-Type": "application/json"})
  )
  
  result = Client(
    settings: ClientSettings(
      baseUrl: baseUrl,
      timeout: timeout
    ),
    httpClient: httpClient
  )

# Close a client
proc close*(client: Client) {.async.} =
  client.httpClient.close()

# Get list of available agents
proc listAgents*(client: Client): Future[seq[AgentDetail]] {.async.} =
  let url = fmt"{client.settings.baseUrl}/agents"
  let response = await client.httpClient.get(url)
  let body = await response.body
  
  if response.code != Http200:
    raise newException(HttpRequestError, fmt"Failed to list agents: {body}")
  
  let data = parseJson(body)
  if not data.hasKey("agents"):
    return @[]
  
  try:
    result = fromJson(seq[AgentDetail], $data["agents"])
  except Exception as e:
    raise newException(Exception, fmt"Failed to parse agent list: {e.msg}")

# Get details for a specific agent
proc getAgent*(client: Client, agentName: string): Future[AgentDetail] {.async.} =
  let url = fmt"{client.settings.baseUrl}/agents/{agentName}"
  let response = await client.httpClient.get(url)
  let body = await response.body
  
  if response.code != Http200:
    raise newException(HttpRequestError, fmt"Failed to get agent: {body}")
  
  try:
    result = fromJson(AgentDetail, body)
  except Exception as e:
    raise newException(Exception, fmt"Failed to parse agent details: {e.msg}")

# Create a run synchronously
proc runSync*(client: Client, agentName: string, 
           input: seq[MessageObj], 
           sessionId: string = ""): Future[RunObj] {.async.} =
  let url = fmt"{client.settings.baseUrl}/runs"
  
  var payload = %*{
    "agent_name": agentName,
    "input": toJson(input).parseJson(),
    "stream": false
  }
  
  if sessionId != "":
    payload["session_id"] = %sessionId
  
  let response = await client.httpClient.post(url, body = $payload)
  let body = await response.body
  
  if response.code != Http200:
    raise newException(HttpRequestError, fmt"Failed to create run: {body}")
  
  try:
    result = fromJson(RunObj, body)
  except Exception as e:
    raise newException(Exception, fmt"Failed to parse run result: {e.msg}")

# Helper to create a run with a text message
proc runSync*(client: Client, agentName: string, 
           textInput: string, 
           sessionId: string = ""): Future[RunObj] {.async.} =
  let message = newTextMessage(textInput)
  result = await client.runSync(agentName, @[message], sessionId)

# Create a streaming run
proc runStream*(client: Client, agentName: string,
               input: seq[MessageObj],
               sessionId: string = "",
               onEvent: proc(data: JsonNode) {.closure.}): Future[RunObj] {.async.} =
  let url = fmt"{client.settings.baseUrl}/runs"
  
  var payload = %*{
    "agent_name": agentName,
    "input": toJson(input).parseJson(),
    "stream": true
  }
  
  if sessionId != "":
    payload["session_id"] = %sessionId
  
  # For streaming, we need to use a custom client
  var streamClient = newAsyncHttpClient()
  streamClient.headers = newHttpHeaders({
    "Content-Type": "application/json",
    "Accept": "text/event-stream"
  })
  
  let response = await streamClient.post(url, body = $payload)
  
  if response.code != Http200:
    let body = await response.body
    raise newException(HttpRequestError, fmt"Failed to create streaming run: {body}")
  
  var lastEvent: JsonNode
  
  # Process the stream
  while true:
    let line = await response.bodyStream.readLine()
    if line.len == 0:
      break
    
    if line.startsWith("data: "):
      let dataStr = line[6 .. ^1]
      try:
        let data = parseJson(dataStr)
        onEvent(data)
        lastEvent = data
      except Exception as e:
        echo fmt"Error parsing SSE data: {e.msg}"
  
  # Close the streaming client
  streamClient.close()
  
  # Return the last event as the final run state
  if lastEvent.isNil:
    raise newException(Exception, "No events received from stream")
  
  try:
    result = fromJson(RunObj, $lastEvent)
  except Exception as e:
    raise newException(Exception, fmt"Failed to parse final run state: {e.msg}")

# Helper to create a streaming run with a text message
proc runStream*(client: Client, agentName: string,
               textInput: string,
               sessionId: string = "",
               onEvent: proc(data: JsonNode) {.closure.}): Future[RunObj] {.async.} =
  let message = newTextMessage(textInput)
  result = await client.runStream(agentName, @[message], sessionId, onEvent)

# Context manager style client usage
template withClient*(baseUrl: string, timeout: int = 30000, body: untyped): untyped =
  block:
    let client {.inject.} = newClient(baseUrl, timeout)
    try:
      body
    finally:
      waitFor client.close()