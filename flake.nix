{
  inputs = {
    nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.zst";
    emacs-overlay = {
      url = "github:nix-community/emacs-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-root.url = "github:srid/flake-root";
    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-systems = {
      url = "github:nix-systems/default";
      flake = false;
    };
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        inputs.flake-root.flakeModule
        inputs.git-hooks.flakeModule
        inputs.treefmt-nix.flakeModule
      ];
      systems = (import inputs.nix-systems);
      perSystem =
        {
          config,
          self',
          inputs',
          pkgs,
          ...
        }:
        {
          # Per-system attributes can be defined here. The self' and inputs'
          # module parameters provide easy access to attributes of the same
          # system.
          packages = {
            default = pkgs.hello;
          };

          pre-commit = {
            check.enable = true;
            settings.package = pkgs.prek;
            settings.hooks = {
              editorconfig-checker.enable = true;
              end-of-file-fixer.enable = true;
              checkmake.enable = true;
              ripsecrets.enable = true;
              trim-trailing-whitespace.enable = true;
              treefmt.enable = true;
              typos.enable = true;
            };
          };

          treefmt.config = {
            projectRootFile = ".git/config";
            package = pkgs.treefmt;
            flakeCheck = false; # use pre-commit's check instead
            programs = {
              nixfmt.enable = true;
              prettier.enable = true;
            };
          };

          devShells.default = pkgs.mkShell {
            # Inherit all of the pre-commit hooks.
            inputsFrom = [
              config.pre-commit.devShell
              config.treefmt.build.devShell
            ];
            packages = config.pre-commit.settings.enabledPackages;
          };
        };
    };
}
