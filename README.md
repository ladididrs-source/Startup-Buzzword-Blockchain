# Startup-Buzzword-Blockchain

A Clarinet-based Clarity project that explores two tongue-in-cheek smart contracts for product ideation and strategy:

- synergy-leverage-optimizer: a minimal on-chain ledger to register ideas, vote on them, and compute a simple "synergy index" and "leverage ratio" for prioritization.
- pivot-prediction-algorithm: a naive signal tracker that records project signals over time and flags when a pivot might be due based on a configurable threshold.

Project goals:
- Keep the implementation simple and clean, using only what’s necessary to make the core features work.
- No cross-contract calls and no trait usage.
- Contract code uses only standard Clarity data types and functions.

## Repository branches

- main: project initialization only (Clarinet scaffolding and docs). No contracts here.
- development: active development branch containing the contracts and PR details.

## Contracts overview

### synergy-leverage-optimizer

Core ideas:
- Register ideas with a title and description.
- Adjust idea attributes (synergy and leverage) and gather votes.
- Compute a basic synergy index using synergy, leverage, and net votes.
- Transfer idea ownership between principals.

This contract intentionally avoids tokens, fees, admin roles, and cross-contract calls. It relies solely on simple maps and variables.

### pivot-prediction-algorithm

Core ideas:
- Register a project with a name.
- Submit integer signals (e.g., -100..100) representing sentiment or traction.
- Maintain a running average and compare it to a project-defined threshold.
- Return whether a “pivot” is suggested based on the moving average vs. threshold.

To keep logic deterministic and efficient without recursion, we store cumulative sums and counts and derive an average at read time.

## Local development

Prerequisites:
- Clarinet installed: https://docs.hiro.so/clarinet
- Node.js (optional) if you want to use the generated package.json scripts.
- Git and GitHub CLI (gh).

Common commands:
- clarinet check — validate contract syntax
- clarinet console — interactively test functions

## Project structure

- Clarinet.toml — project configuration
- contracts/ — Clarity smart contracts (on development branch)
- tests/ — test scaffolding
- settings/ — network settings

## License

MIT