# Issue tracker: GitHub

Issues and specs for this repository live in GitHub Issues at
`def-peter/CueDex`. Use the `gh` CLI for all operations.

## Conventions

- Create: `gh issue create --title "..." --body "..."`
- Read: `gh issue view <number> --comments`
- List: `gh issue list` with appropriate state and label filters
- Comment: `gh issue comment <number> --body "..."`
- Label: `gh issue edit <number> --add-label "..."` or `--remove-label "..."`
- Close: `gh issue close <number> --comment "..."`

Infer the repository from the current Git remote.

## Pull requests as a triage surface

**PRs as a request surface: no.**

## Skill terminology

- "Publish to the issue tracker" means creating a GitHub issue.
- "Fetch the relevant ticket" means reading the corresponding GitHub issue.
- Wayfinder maps and child tickets are represented with GitHub Issues,
  sub-issues, dependencies, labels, and assignees.
