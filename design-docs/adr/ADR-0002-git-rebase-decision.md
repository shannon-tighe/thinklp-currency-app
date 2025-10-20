# ADR-0002 Git Strategy Decisions
Date: 10-15-2025
Status: Accepted

## Context
Main branch for remote and local repo were out of sync after initial setup error. Needed to update git config file with a pull strategy to handle desynced branches.

## Decision
Use Command: git config pull.rebase false

## Consequences
When branches divere we will see extra commits in commit history on every pull where both sides changed.