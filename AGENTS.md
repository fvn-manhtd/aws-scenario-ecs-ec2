# Repository Guidelines

## Project Structure & Module Organization
- `infra/`: Terraform for AWS ECS on EC2. Files are split by concern (`vpc.tf`, `alb.tf`, `ecs_cluster.tf`, `ecs_service*.tf`, `ecr.tf`, `route53.tf`, `cloudfront.tf`, etc.). Requires Terraform `>= 1.3` and AWS provider `~> 4.0`.
- `app/`: Docker build context for the Next.js app.
  - `Dockerfile` (prod), `Dockerfile.development`, `docker-compose.yml`.
  - `app/src/`: Next.js 13 + TypeScript + Tailwind (`pages/`, `styles/`, `next.config.js`, `package.json`).
- Root: `Makefile`, `deploy.sh`, `destroy.sh`, `.env.example`, `README.md`. Docs in `docs/`.

## Build, Test, and Development Commands
- `make bootstrap`: Copy `.env.example` → `.env` (edit credentials and config).
- `make deploy`: `terraform init/plan/apply`, ECR login, build/tag/push image, update ECS service.
- `make destroy`: Scale tasks to 0, deregister task, delete service, `terraform destroy`.
- Housekeeping: `make destroy.clean`, `make clean`, `make clean.all`.
- App local dev: `cd app && docker compose up --build` (or `docker-compose`), or `cd app/src && npm run dev | build | start | lint`.

## Coding Style & Naming Conventions
- TypeScript strict mode is enabled (`app/src/tsconfig.json`). Use 2‑space indentation; run `npm run lint` (ESLint + `eslint-config-next`).
- React components: PascalCase. Page files under `pages/`: route‑based lowercase (e.g., `pages/index.tsx`).
- Terraform: follow existing name pattern `${var.namespace}_<Resource>_${var.environment}` and keep tags like `Scenario`/`Name` consistent.

## Testing Guidelines
- No tests currently. If adding tests: use Jest + React Testing Library for unit (`*.test.tsx`) and/or Playwright for e2e.
- Co‑locate tests with code; add `npm test` script and document usage. Target ≥70% coverage for new code.

## Commit & Pull Request Guidelines
- Commits: short, imperative, and scoped (e.g., "Add ECS autoscaling policy"). Separate app vs infra changes when practical.
- PRs include: summary, rationale, linked issues, verification steps (commands run), and screenshots for UI/ECS console when relevant.
- Never commit secrets/state. Ensure `make deploy` completes locally for infra changes.

## Security & Configuration Tips
- Do not commit `.env` or Terraform state (see `.gitignore`). Configure AWS creds via `.env` only for local use.
- Apply least‑privilege IAM; run `make destroy` to avoid unintended AWS costs. Keep `deploy.sh` step order intact (ECR login before pushes).

## Agent‑Specific Notes
- Keep changes minimal and focused; do not rename Make targets or Terraform files without need. Update outputs/docs if infra changes affect them.
- Preserve the deployment flow and variable semantics (e.g., `hash` versioning) when adjusting pipelines.

