{ pkgs ? import <nixpkgs> { } }:

with pkgs;
mkShell {
  buildInputs = [
    git
    terraform
    terraform-docs
    terragrunt
  ];
}
