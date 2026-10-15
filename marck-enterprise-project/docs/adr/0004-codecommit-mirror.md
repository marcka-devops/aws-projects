# ADR 0004: GitHub is the working repository; CodeCommit is the pipeline source

- **Status:** Accepted
- **Date:** 2026-10-14

## Context

The DevOps case study asks to migrate the GitHub repository into CodeCommit and use CodeCommit as the CodePipeline source. The project also needs to live on GitHub to be public.

## Decision

Work happens on GitHub. A workflow mirrors `main` to CodeCommit on every push through an OIDC role limited to `GitPush` on that one repository. CodePipeline starts from CodeCommit through an EventBridge rule. Setting `source_provider = "github"` switches the pipeline to GitHub through CodeConnections.

## Consequences

- Meets the brief and keeps GitHub as the single place for reviews.
- CodeCommit is always a copy; never push to it directly.
