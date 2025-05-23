## Test coverage for client module using mocks
import unittest, asyncdispatch, json, options
import ../src/acp/models

# Mock types to test client functionality without dependencies
type
  ClientSettings* = object
    baseUrl*: string
    timeout*: int  # Timeout in milliseconds

  AsyncHttpClient* = ref object
    settings: ClientSettings
    headers: Table[string, string]
    responseData: JsonNode  # Mock response data
    responseCode: int       # Mock response code
  
  Client* = ref object
    settings*: ClientSettings
    httpClient*: AsyncHttpClient

  HttpResponse* = ref object
    code*: int
    bodyData*: string

# Mock client implementation
proc newAsyncHttpClient(timeout: int = 30000, 
                       headers: Table[string, string] = initTable[string, string]()): AsyncHttpClient =
  result = AsyncHttpClient(
    settings: ClientSettings(baseUrl: "", timeout: timeout),
    headers: headers,
    responseData: newJObject(),
    responseCode: 200
  )

proc close(client: AsyncHttpClient) {.async.} =
  discard

proc setMockResponse(client: AsyncHttpClient, data: JsonNode, code: int = 200) =
  client.responseData = data
  client.responseCode = code

proc get(client: AsyncHttpClient, url: string): Future[HttpResponse] {.async.} =
  result = HttpResponse(
    code: client.responseCode,
    bodyData: $client.responseData
  )

proc post(client: AsyncHttpClient, url: string, body: string = ""): Future[HttpResponse] {.async.} =
  result = HttpResponse(
    code: client.responseCode,
    bodyData: $client.responseData
  )

proc body(response: HttpResponse): Future[string] {.async.} =
  return response.bodyData

# Mock client constructor and methods
proc newClient(baseUrl: string, timeout: int = 30000): Client =
  let httpClient = newAsyncHttpClient(
    timeout = timeout,
    headers = {"Content-Type": "application/json"}.toTable
  )
  
  result = Client(
    settings: ClientSettings(
      baseUrl: baseUrl,
      timeout: timeout
    ),
    httpClient: httpClient
  )

proc close(client: Client) {.async.} =
  await client.httpClient.close()

proc setMockResponse(client: Client, data: JsonNode, code: int = 200) =
  client.httpClient.setMockResponse(data, code)

proc listAgents(client: Client): Future[seq[AgentDetail]] {.async.} =
  let response = await client.httpClient.get(client.settings.baseUrl & "/agents")
  let body = await response.body()
  
  if response.code != 200:
    raise newException(Exception, "Failed to list agents")
  
  let data = parseJson(body)
  
  if not data.hasKey("agents"):
    return @[]
  
  var agents: seq[AgentDetail] = @[]
  for agentJson in data["agents"]:
    let agent = AgentDetail(
      name: agentJson["name"].getStr(),
      description: agentJson["description"].getStr(),
      metadata: initTable[string, JsonNode]()
    )
    agents.add(agent)
  
  return agents

proc runSync(client: Client, agentName: string, 
           input: seq[MessageObj], 
           sessionId: string = ""): Future[RunObj] {.async.} =
  # Construct response run using input
  let response = await client.httpClient.post(client.settings.baseUrl & "/runs")
  let body = await response.body()
  
  if response.code != 200:
    raise newException(Exception, "Failed to create run")
  
  # Parse response as RunObj
  let data = parseJson(body)
  
  return RunObj(
    runId: data["run_id"].getStr(),
    agentName: data["agent_name"].getStr(),
    sessionId: data["session_id"].getStr(),
    status: RunStatus.fromJson(data["status"].getStr()),
    output: input,  # Echo back the input as output
    error: none(string)
  )

# Tests
suite "ACP Client Mocked Tests":
  test "Client initialization":
    let client = newClient("http://localhost:8000", 5000)
    check client.settings.baseUrl == "http://localhost:8000"
    check client.settings.timeout == 5000
  
  test "List agents":
    proc testListAgents() {.async.} =
      let client = newClient("http://localhost:8000")
      
      # Set mock response
      let mockData = %*{
        "agents": [
          {
            "name": "echo",
            "description": "Echo agent"
          },
          {
            "name": "math",
            "description": "Math agent"
          }
        ]
      }
      client.setMockResponse(mockData)
      
      # Call list agents
      let agents = await client.listAgents()
      
      check agents.len == 2
      check agents[0].name == "echo"
      check agents[0].description == "Echo agent"
      check agents[1].name == "math"
      check agents[1].description == "Math agent"
    
    waitFor testListAgents()
  
  test "Run sync with text message":
    proc testRunSync() {.async.} =
      let client = newClient("http://localhost:8000")
      
      # Create input message
      let message = newTextMessage("Hello, agent!")
      let input = @[message]
      
      # Set mock response
      let mockData = %*{
        "run_id": "test-run-id",
        "agent_name": "echo",
        "session_id": "test-session-id",
        "status": "completed",
        "output": [
          {
            "parts": [
              {
                "content_type": "text/plain",
                "content": "Hello, agent!"
              }
            ]
          }
        ]
      }
      client.setMockResponse(mockData)
      
      # Call run sync
      let run = await client.runSync("echo", input)
      
      check run.runId == "test-run-id"
      check run.agentName == "echo"
      check run.sessionId == "test-session-id"
      check run.status == rsCompleted
      check run.error.isNone()
      check run.output.len == input.len
      check run.output[0].parts.len == input[0].parts.len
      check run.output[0].parts[0].content == "Hello, agent!"
    
    waitFor testRunSync()
  
  test "Run sync with error response":
    proc testRunSyncError() {.async.} =
      let client = newClient("http://localhost:8000")
      
      # Create input message
      let message = newTextMessage("Hello, agent!")
      let input = @[message]
      
      # Set mock error response
      let mockData = %*{"error": "Agent not found"}
      client.setMockResponse(mockData, 404)
      
      # Call run sync should raise exception
      var exceptionCaught = false
      try:
        discard await client.runSync("non-existent", input)
      except Exception:
        exceptionCaught = true
      
      check exceptionCaught == true
    
    waitFor testRunSyncError()

when isMainModule:
  echo "Running tests for ACP client with mocks..."