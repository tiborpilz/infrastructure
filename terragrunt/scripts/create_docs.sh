#!/usr/bin/env bash
# This script creates the documentation for all the terraform modules using terraform-docs.

basedir=$(dirname $0)
modules=$(find . -name "main.tf" -exec dirname {} \; | sort -u)
echo "Found modules: $modules"

for module in $modules; do
  terraform-docs markdown $module > $module/README.md
done
