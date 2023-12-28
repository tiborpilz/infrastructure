#!/usr/bin/env bash
# This script creates the documentation for all the terraform modules using terraform-docs.

# Abort if terraform-docs is not installed
if ! command -v terraform-docs &> /dev/null
then
    echo "terraform-docs could not be found"
    exit
fi

echo "Creating documentation for all modules..."

basedir=$(dirname $0)
modules=$(find . -name "main.tf" -exec dirname {} \; | sort -u)

for module in $modules; do
  terraform-docs markdown $module > $module/README.md
done
