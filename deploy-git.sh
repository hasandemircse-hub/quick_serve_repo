#!/bin/bash
# deploy-git.sh — GitHub Actions CI/CD'ye alternatif olarak
# GitHub üzerinden Docker ile CI/CD işlemlerini tetikler

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "======================================"
echo " QuickServe - GitHub CI/CD Trigger"
echo "======================================"

GITHUB_TOKEN="${GH_TOKEN:?GH_TOKEN environment variable is required}"
GITHUB_REPO="${GH_REPO:-your-org/quick-serve}"
BRANCH="${GH_BRANCH:-main}"

echo "Triggering GitHub Actions workflow on $BRANCH..."

curl -s -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "https://api.github.com/repos/$GITHUB_REPO/actions/workflows/ci-cd.yml/dispatches" \
  -d "{\"ref\":\"$BRANCH\"}"

echo ""
echo "GitHub Actions workflow triggered on branch: $BRANCH"
echo "Check status: https://github.com/$GITHUB_REPO/actions"
