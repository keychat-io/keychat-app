---
name: batch
description: "Orchestrate large-scale changes across the codebase using parallel worktree agents. Use when you need to apply similar changes to many files or modules simultaneously."
invoke: user
---

# Batch

Research and plan a large-scale change, then execute it in parallel across isolated worktree agents.

## Workflow

### Phase 1: Research & Plan
1. Understand the requested change thoroughly
2. Identify all files and modules that need modification
3. Group changes into independent, parallelizable units (max 10 units)
4. Present the plan to the user for approval before proceeding

### Phase 2: Execute
1. For each unit of work, launch an Agent with `isolation: "worktree"` to make the changes independently
2. Run agents in parallel where possible (up to 5 concurrent agents)
3. Each agent should:
   - Make the required changes
   - Run relevant tests or lint checks
   - Commit changes with a clear message

### Phase 3: Review & Merge
1. Collect results from all agents
2. Report successes and failures
3. For successful changes, present diffs for user review
4. Help merge changes back to the main branch

## Rules
- Always get user approval before executing changes
- Never modify more than what was requested
- If a unit fails, continue with others and report the failure
- Keep the user informed of progress throughout
