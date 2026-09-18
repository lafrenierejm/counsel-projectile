#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

if [ -n "$(git status --porcelain)" ]; then
	echo "error: working tree is not clean" >&2
	exit 1
fi

new_version=$(convco version --bump --prefix "")

sed -i -E "s/^;; Version: .*/;; Version: ${new_version}/" counsel-projectile.el

git add counsel-projectile.el
git commit -m "chore(release): ${new_version}"
git tag -a "${new_version}" -m "counsel-projectile: ${new_version}"
git push --follow-tags
gh release create "${new_version}" --title "${new_version}" --generate-notes
