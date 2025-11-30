---
agent: agent
description: Use xcodebuild to verify that an Xcode project or workspace builds successfully.
tools: ['execute/runInTerminal', 'apple-docs/*', 'agent']
---
Use xcodebuild to verify that the Xcode project or workspace builds successfully.

Project Configuration:
- Location: Ye-Dufu/folder
- Scheme: Ye-Dufu
- Destination: iPhone 17 Pro simulator

Instructions:
1. Run xcodebuild with the specified configuration
2. If the build fails, analyze the error messages
3. Fix code issues as needed to resolve build failures
4. Re-run the build to verify success