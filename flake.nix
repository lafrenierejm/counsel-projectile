{
  inputs = {
    nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.zst";
    nixpkgs-24_05.url = "github:NixOS/nixpkgs/nixos-24.05"; # Emacs 29
    nixpkgs-24_11.url = "github:NixOS/nixpkgs/nixos-24.11"; # Emacs 30
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
          system,
          ...
        }:
        let
          # Use emacs-overlay's MELPA/ELPA recipe archives without pulling in
          # its extra Emacs builds.  This lets us build against bleeding edge
          # Emacs package dependencies.
          withMelpaOverlay =
            nixpkgsFlake:
            import nixpkgsFlake {
              inherit system;
              overlays = [ inputs.emacs-overlay.overlays.package ];
            };

          pkgsEmacs29 = withMelpaOverlay inputs.nixpkgs-24_05;
          pkgsEmacs30 = withMelpaOverlay inputs.nixpkgs-24_11;
          pkgsEmacs31 = withMelpaOverlay inputs.nixpkgs;

          emacsPackages29 = pkgsEmacs29.emacsPackagesFor (
            # The nixos-24.05 cache ships a native-comp Emacs 29 build whose
            # linked libgccjit crashes dyld on current macOS; disabling
            # native-comp forces a local build against this host's toolchain
            # instead of using that broken cached binary.
            pkgsEmacs29.emacs.override { withNativeCompilation = !pkgs.stdenv.isDarwin; }
          );
          emacsPackages30 = pkgsEmacs30.emacsPackagesFor pkgsEmacs30.emacs;
          emacsPackages31 = pkgsEmacs31.emacsPackagesFor pkgsEmacs31.emacs;

          counselProjectileFor =
            emacsPackages:
            emacsPackages.melpaBuild {
              pname = "counsel-projectile";
              version = "0.0.0";
              commit = "unknown";
              src = ./.;
              recipe = pkgs.writeText "counsel-projectile-recipe" ''
                (counsel-projectile :fetcher git :url "" :files ("counsel-projectile.el"))
              '';
              packageRequires = with emacsPackages; [
                counsel
                projectile
              ];
            };

          loadTest =
            name: emacsPackages: package:
            let
              emacs = emacsPackages.emacsWithPackages (epkgs: [ package ]);
            in
            pkgs.runCommand "counsel-projectile-load-${name}" { } ''
              cp ${./counsel-projectile.el} counsel-projectile.el
              ${emacs}/bin/emacs --batch -f batch-byte-compile counsel-projectile.el
              ${emacs}/bin/emacs --batch --eval "(require 'counsel-projectile)"
              touch $out
            '';
        in
        {
          packages = {
            counsel-projectile-emacs-29 = counselProjectileFor emacsPackages29;
            counsel-projectile-emacs-30 = counselProjectileFor emacsPackages30;
            counsel-projectile-emacs-31 = counselProjectileFor emacsPackages31;
            default = self'.packages.counsel-projectile-emacs-31;
          };

          checks = {
            counsel-projectile-load-emacs-29 =
              loadTest "emacs-29" emacsPackages29
                self'.packages.counsel-projectile-emacs-29;
            counsel-projectile-load-emacs-30 =
              loadTest "emacs-30" emacsPackages30
                self'.packages.counsel-projectile-emacs-30;
            counsel-projectile-load-emacs-31 =
              loadTest "emacs-31" emacsPackages31
                self'.packages.counsel-projectile-emacs-31;
          };

          pre-commit = {
            check.enable = true;
            settings.package = pkgs.prek;
            settings.hooks = {
              convco.enable = true;
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
            inputsFrom = [
              config.pre-commit.devShell
              config.treefmt.build.devShell
            ];
            packages = config.pre-commit.settings.enabledPackages;
          };
        };
    };
}
