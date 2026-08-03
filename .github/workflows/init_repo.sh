#!/usr/bin/env bash

full_name=$1

echo $full_name

repo=$(echo $full_name | awk -F '/' '{print $2}')

# Sanitize the repo name to be a valid Python package name
sanitized_repo=$(echo "$repo" | sed 's/[^a-zA-Z0-9_-]/_/g')

echo $sanitized_repo
# Delete the "Use this template" section from README.md
sed -i '/## Create repository from this template./,/##/d' README.md


# Update package name in pyproject.toml
sed -i "s/bits_instrument/${sanitized_repo}/g" pyproject.toml

# Update the pixi env name + editable self-install key to match, so `pixi install`
# works (the editable key must equal [project].name in pyproject.toml).
sed -i "s/bits_instrument/${sanitized_repo}/g" pixi.toml

# Delete the template-specific Claude Code guidance (describes this template, not the instrument)
rm -rf CLAUDE.md

rm -rf .github/resources
rm -rf .github/workflows/init_repo.sh
rm -rf .github/workflows/init_repo.yml
