---
name: verify
description: Builds the project and runs all tests to verify correctness after changes
---

Run the full build + test cycle.

## Inside Xcode

When the xcode-tools MCP server is available (its tools are named
`mcp__xcode-tools__…`), use it rather than `xcodebuild`, so the build shares
Xcode's build state and its results show in Xcode:

1. Build with `BuildProject`. It builds the scheme selected in Xcode, which
   should be Keeps; if it isn't, switch with `XcodeSwitchScheme` first. If
   the build fails, use `GetBuildLog` for the errors.
2. If the build succeeds, run the tests with `RunAllTests`.

## Elsewhere

Without the xcode-tools server, use the command line:

1. Build:
```bash
xcodebuild -project Keeps.xcodeproj -scheme Keeps -destination 'platform=macOS' build
```

2. If the build succeeds, run tests:
```bash
xcodebuild test -project Keeps.xcodeproj -scheme Keeps -destination 'platform=macOS'
```

Report any build errors or test failures. If everything passes, confirm success.
