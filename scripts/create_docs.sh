#!/usr/bin/env bash
# This script creates the documentation for all the terraform modules using terraform-docs.

function echo_if_tty() {
  if [[ $- == *i* ]]; then echo $1; fi
}

# Abort if terraform-docs is not installed
if ! command -v terraform-docs &> /dev/null
then
  echo_if_tty "terraform-docs could not be found"
  exit
fi

echo_if_tty "Creating documentation for all modules..."

basedir=$(dirname $0)
modules=$(find . -name "main.tf" -exec dirname {} \; | sort -u)

for module in $modules; do
  terraform-docs markdown $module > $module/README.md
  echo $module/README.md
done
