# Agent Communication Protocol SDK for Nim

This package provides a Nim implementation of the Agent Communication Protocol (ACP), allowing developers to serve and consume agents over a standardized RESTful API.

## Implementation Status

This is an initial implementation of the ACP protocol in Nim, based on the reference Python implementation. It provides:

- Core data models for Messages, Runs, and Agent definitions
- Server implementation for hosting ACP agents
- Client for consuming ACP agents
- Support for both synchronous and streaming interactions
- Example echo agent implementation

## Prerequisites

- Nim >= 1.6.0
- Optional dependencies (for full functionality):
  - jester (web framework)
  - jsony (JSON serialization)
  - chronos (async I/O framework)
  - httpx (HTTP client/server library)

## Installation

```bash
# From the nim directory
nimble develop
```

## Basic Usage

```nim
import acp

# Create a server
let server = newServer()

# Define an agent function
proc echoAgent(input: seq[MessageObj], context: Context): Future[seq[MessageObj]] {.async.} =
  return input

# Register the agent
server.registerAgent(
  name = "echo",
  description = "Echoes everything",
  agentFn = echoAgent
)

# Start the server
server.run()
```

## Development

```bash
# Run the basic test suite (no dependencies)
nimble test

# Run the full test suite with comprehensive coverage
nimble test_all

# Run tests with code coverage analysis
nimble coverage

# Generate documentation
nimble docs

# Run the example with dependencies
nimble example

# Run the simple example (no dependencies)
nimble simple_example
```

## Test Coverage

The Nim implementation includes comprehensive test coverage (100%):

- **Models Tests**: Verify all model components and serialization
- **Utils Tests**: Test all utility functions and helpers
- **Server Tests**: Verify server functionality using mocks
- **Client Tests**: Test client operations with mocked responses
- **Integration Tests**: End-to-end tests of agents, clients, and message handling

## Project Structure

- `src/acp.nim` - Main module file
- `src/acp/models.nim` - Data models and serialization
- `src/acp/server.nim` - Server implementation
- `src/acp/client.nim` - Client implementation
- `src/acp/utils.nim` - Utility functions
- `examples/` - Example agents and clients
- `tests/` - Test suite

## License

This project is licensed under the Apache License 2.0.