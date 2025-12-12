---
agent: github
tools: ['execute/getTerminalOutput', 'execute/runInTerminal', 'github/create_pull_request']
---
1. **Branch Management**:
   - Check the current branch.
   - If currently on `main` or `master`, create a new branch with a descriptive name based on the uncommitted changes.
   - If already on a feature branch, proceed with it.

2. **Commit Changes**:
   - Stage all changes (`git add .`).
   - Generate a descriptive commit message summarizing the changes.
   - Commit the changes.

3. **Push**:
   - Push the current branch to `origin`.
   - Ensure the upstream is set (`git push -u origin <branch_name>`).

4. **Open Pull Request**:
   - Create a Pull Request to merge the current branch into `main`.
   - Generate a title that summarizes the feature or fix.
   - Generate a description that lists the key changes and context.