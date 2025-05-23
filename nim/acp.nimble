# Package

version       = "0.0.0"
author        = "jasagiri"
description   = "Agent Communication Protocol SDK for Nim"
license       = "Apache-2.0"
srcDir        = "src"

# Dependencies

requires "nim >= 1.6.0"

# Optional dependencies that will be used if available
# requires "jester >= 0.5.0"      # Web framework
# requires "jsony >= 1.1.3"       # JSON serialization
# requires "chronos >= 3.0.1"     # Async I/O framework
# requires "httpx >= 0.2.0"       # HTTP client/server library

task test, "Run the basic test suite":
  exec "nim c -r tests/standalone_test"

task tests, "Run the full test suite with all coverage tests":
  exec "nim c -r tests/test_all"

task coverage, "Run tests with coverage analysis":
  exec "nim c --passC:--coverage --passL:--coverage -r tests/test_all"
  echo "Generate coverage report with: gcov -o nimcache/tests/test_all/*.gcda *.nim"

task docs, "Generate documentation":
  exec "nim doc --project --index:on --outdir:htmldocs src/acp.nim"

task example, "Compile the echo agent example (requires dependencies)":
  exec "nim c -r examples/echo_agent.nim"

task simple_example, "Compile the simple agent example (no dependencies)":
  exec "nim c -r examples/simple_agent.nim"
