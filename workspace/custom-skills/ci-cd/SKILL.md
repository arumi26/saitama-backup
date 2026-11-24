---
skill: ci-cd
title: "CI/CD & Supply Chain"
category: "Security · Cloud/Infra"
load_when: "Public repos, build configs, package manifests."
pack: SUPERAGENT V10
bughunt: true
---
# CI/CD & Supply Chain

## Where it pays
Pipeline compromise = secrets + prod; dependency confusion = org-wide RCE.

## Signals
.github/workflows, .gitlab-ci.yml, Jenkinsfiles; internal package names.

## Methodology
1. Config for pull_request_target misuse, untrusted input→run, secret echo.
2. Pipeline injection via PR title/branch/filename.
3. Secret leakage in logs/artifacts/fork PRs.
4. Dependency confusion / typosquat / unpinned actions (benign PoC).

## Validation gate
Code exec in pipeline, secret exfil, or resolvable confusion package — benign only.

## Impact & chains
secret theft → cloud; runner RCE → prod.

**→ next: `../cloud-infra/cloud-misconfig.md`.**
