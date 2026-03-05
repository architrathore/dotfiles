---
name: conventional-commits
description: Commit code changes using Conventional Commits convention. Use either before planning to generate commit-by-commit plan, or after changes to organizes large changes into smaller meaningful commits.
---

Organize code changes into well-structured commits following the [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) specification.

## Format

```
<type>(<optional scope>): <description>

[optional body]

[optional footer(s)]
```

## Types

`feat` · `fix` · `docs` · `style` · `refactor` · `perf` · `test` · `build` · `ci` · `chore` · `revert`

## Rules

- **description**: lowercase, imperative mood, no trailing period.
- **scope**: optional, contextualizes the change (e.g., `feat(auth):`).
- **body**: separated by blank line, explains *what* and *why*.
- **Breaking changes**: append ! character after type/scope and/or add `BREAKING CHANGE:` footer.
- Each commit should be one logical, atomic change. Don't mix unrelated changes.
- Order commits so foundational changes come first.

## Examples

```
feat(auth): add OAuth2 login support
fix(api): prevent null pointer on empty response body
refactor(db): extract connection pooling into shared module
docs(readme): add setup instructions for local development
```

Breaking change with body and footer:

```
feat(api)!: change pagination response format

The items field is now nested under data and pagination
metadata moved to a top-level pagination object.

BREAKING CHANGE: API response shape for paginated endpoints has changed.
Refs: #452
```

## Modes

**Pre-planning** — When invoked before writing code, produce a numbered commit plan. Each entry: the commit message, brief description of changes, and files to be touched.

**Post-change** — When invoked after changes are made, analyze the working tree and stage/commit following the workflow above. Present the full plan and ask for approval before executing.
