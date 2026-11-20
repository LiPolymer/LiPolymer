#!/bin/sh
set -eu

# Renders the GitHub profile tree from main and commits it to the dedicated
# GitLab branch so GitLab Push Mirroring can sync it to GitHub automatically.

TARGET_BRANCH="${GITHUB_BRANCH:-github}"

if [ -n "${GITLAB_PUSH_TOKEN:-}" ]; then
  AUTH_PREFIX="oauth2:${GITLAB_PUSH_TOKEN}"
elif [ -n "${CI_JOB_TOKEN:-}" ]; then
  AUTH_PREFIX="gitlab-ci-token:${CI_JOB_TOKEN}"
else
  echo "Error: neither GITLAB_PUSH_TOKEN nor CI_JOB_TOKEN is set." >&2
  exit 1
fi

SERVER_PROTO="${CI_SERVER_URL%%://*}"
SERVER_HOST="${CI_SERVER_URL#*://}"
SERVER_HOST="${SERVER_HOST%/}"
REPO_URL="${SERVER_PROTO}://${AUTH_PREFIX}@${SERVER_HOST}/${CI_PROJECT_PATH}.git"

WORK_DIR="/tmp/gh-branch"
rm -rf "$WORK_DIR"

export GIT_TERMINAL_PROMPT=0

set +e
git ls-remote --exit-code --heads "$REPO_URL" "$TARGET_BRANCH" >/dev/null 2>&1
LS_RC=$?
set -e

if [ "$LS_RC" -eq 0 ]; then
  git clone --depth=1 --branch "$TARGET_BRANCH" "$REPO_URL" "$WORK_DIR"
elif [ "$LS_RC" -eq 2 ]; then
  git init "$WORK_DIR"
  git -C "$WORK_DIR" checkout -b "$TARGET_BRANCH"
  git -C "$WORK_DIR" remote add origin "$REPO_URL"
else
  echo "Error: failed to query remote branch '$TARGET_BRANCH' (exit $LS_RC)." >&2
  exit "$LS_RC"
fi

# Replace working tree (except .git) with a clean snapshot of main
find "$WORK_DIR" -mindepth 1 -maxdepth 1 ! -name ".git" -exec rm -rf {} +
git -C "$CI_PROJECT_DIR" archive HEAD | tar -x -C "$WORK_DIR"

# Drop GitLab-only files and render the GitHub README
rm -rf "$WORK_DIR/.gitlab" "$WORK_DIR/.gitlab-ci.yml" \
  "$WORK_DIR/assets/banner.svg" "$WORK_DIR/assets/banner_c.svg"

awk -f "$CI_PROJECT_DIR/.gitlab/render-github-readme.awk" \
  "$CI_PROJECT_DIR/README.md" > "$WORK_DIR/README.md"

cd "$WORK_DIR"
git add -A

if git diff --cached --quiet; then
  echo "No changes to sync to branch '$TARGET_BRANCH'."
  exit 0
fi

AUTHOR_NAME=$(git -C "$CI_PROJECT_DIR" log -1 --format='%an')
AUTHOR_EMAIL=$(git -C "$CI_PROJECT_DIR" log -1 --format='%ae')
COMMIT_SUBJECT=$(git -C "$CI_PROJECT_DIR" log -1 --format='%s')
SHORT_SHA="${CI_COMMIT_SHORT_SHA:-$(git -C "$CI_PROJECT_DIR" rev-parse --short HEAD)}"

git config user.name "${AUTHOR_NAME:-GitLab CI}"
git config user.email "${AUTHOR_EMAIL:-ci@lipoly.ink}"

GIT_AUTHOR_NAME="$AUTHOR_NAME" \
GIT_AUTHOR_EMAIL="$AUTHOR_EMAIL" \
git commit -m "$COMMIT_SUBJECT" -m "Synced from main (${SHORT_SHA}) [skip ci]"

git push origin "HEAD:${TARGET_BRANCH}"
