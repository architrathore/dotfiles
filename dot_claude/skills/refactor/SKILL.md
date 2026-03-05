---
name: refactor-pass
description: Perform a refactor pass focused on simplicity after recent changes. Use when the user asks for a refactor, cleanup pass, simplification, or dead code removal. Expects builds/tests to verify behavior.
---

# Refactor Pass

Review the recent changes in the current branch and apply a simplification-focused refactor:

1. **Identify scope**: Run `git diff` (staged + unstaged) and `git diff HEAD~1` to understand what changed recently.
   - It is also possible, that the refactor's scope is the whole current branch, in which case the
   diff should be against the master/main branch (e.g., `git diff master`).
2. **Simplify**:
   - Straighten convoluted logic flows (flatten nesting, early returns).
   - Remove excessive or redundant parameters.
   - Inline trivial one-use helpers that obscure intent.
3. **Comments**:
   - Restore any useful comments that were accidentally deleted.
   - Add brief comments only where logic is non-obvious. Do not add boilerplate or redundant comments.
4. **Patterns**: If a clear abstraction or reusable pattern emerges, suggest it in a one-line comment — only if it genuinely improves clarity.
5. **Verify**: Run the project's build and test commands to confirm nothing broke. Report any failures.

Keep changes minimal and each refactor obvious in intent. Do not introduce new features or change behavior.
