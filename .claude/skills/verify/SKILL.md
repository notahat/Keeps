---
name: verify
description: Builds the project and runs all tests to verify correctness after changes
---

Run the full build + test cycle:

1. Build:
```bash
xcodebuild -project Keeps.xcodeproj -scheme Keeps -destination 'platform=macOS' build
```

2. If the build succeeds, run tests:
```bash
xcodebuild test -project Keeps.xcodeproj -scheme Keeps -destination 'platform=macOS'
```

Report any build errors or test failures. If everything passes, confirm success.
