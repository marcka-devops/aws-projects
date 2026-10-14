# Contributing

Changes reach AWS only through pull requests. Nobody applies Terraform or deploys the app from a laptop after the first bootstrap.

## Workflow

1. Branch from `main`: `feat/<topic>`, `fix/<topic>`, `docs/<topic>` or `chore/<topic>`.
2. Make the change and run the local checks:
   ```bash
   pre-commit install -c marck-enterprise-project/.pre-commit-config.yaml   # once, from the repository root
   make check                # fmt, validate, unit tests
   ```
3. Open a pull request and fill in the template. CI runs every check, and the Terraform workflow posts a plan for each stack.
4. A code owner reviews the plan as well as the diff. Merge only when both look right.
5. On merge, the `production` environment asks for approval, then Terraform applies the stacks in order. App changes ship through CodePipeline (QA → production → Elastic Beanstalk).

## Commit messages

Use [Conventional Commits](https://www.conventionalcommits.org/):

```
feat(network): add a VPC endpoint for CloudWatch Logs
fix(app): return 200 from health.php before the first deploy
docs(runbooks): add Aurora switchover steps
```

Scopes match the top-level folders and stacks: `network`, `security`, `data`, `storage`, `compute`, `delivery`, `self-service`, `app`, `functions`, `ansible`, `packer`, `ci`, `docs`.

## Conventions

| Area | Rule |
| --- | --- |
| Terraform layout | Every stack has `versions.tf`, `providers.tf`, `variables.tf`, `outputs.tf`, and `remote_state.tf` when it reads another stack. Resources are grouped by concern (`aurora.tf`, `cache.tf`). |
| Naming | Resources are named `${var.project}-<purpose>`, lowercase with hyphens. |
| Tags | Set through `default_tags` in `providers.tf`: `Project`, `Environment`, `Stack`, `ManagedBy`. |
| Secrets | Never in code or variables files. Use Secrets Manager and reference it. |
| Cross-stack values | Read through `terraform_remote_state`; add an output to the producing stack instead of hard-coding IDs. |
| New stack | Add it to `STACKS` in the `Makefile`, the matrix in `.github/workflows/marck-enterprise-terraform.yml` (repository root), Dependabot, and `infra/README.md`. |
| Docs | If a change affects how something is operated, update `docs/runbooks.md`. If it changes a design choice, add an ADR in `docs/adr/`. |
