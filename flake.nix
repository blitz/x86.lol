{
  description = "The x86.lol blog source";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";

    pre-commit-hooks-nix = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        # Formatting and quality checks.
        inputs.pre-commit-hooks-nix.flakeModule
      ];

      systems = [
        "x86_64-linux"

        # Disabled, because pre-commit fails.
        #
        # "aarch64-linux"
      ];

      perSystem = { config, system, pkgs, ... }: {
        pre-commit = {
          check.enable = true;

          settings.hooks = {
            nixpkgs-fmt = {
              enable = true;

              # This is autogenerated by bundix.
              excludes = [ "gemset\\.nix" ];
            };

            typos = {
              enable = true;

              excludes = [
                ".*\\.png$"
                ".*\\.webp$"
                "gemset\\.nix"
              ];
            };
          };
        };

        packages = {
          jekyll_env = pkgs.bundlerEnv {
            name = "jekyll_env";
            gemfile = ./Gemfile;
            lockfile = ./Gemfile.lock;
            gemset = ./gemset.nix;
          };

          blog = pkgs.stdenv.mkDerivation {
            name = "x86-lol";

            src = ./.;
            nativeBuildInputs = [ config.packages.jekyll_env ];

            dontConfigure = true;

            buildPhase = "jekyll build";
            installPhase = ''
              mkdir -p $out
              cp -r _site/* $out/
            '';
          };

          default = config.packages.blog;
        };

        devShells = {
          watch = pkgs.mkShell {
            packages = [ config.packages.jekyll_env ];

            shellHook = ''
              exec jekyll serve --watch --drafts --livereload
            '';
          };

          default = pkgs.mkShell {
            packages = [
              config.packages.jekyll_env

              # For updating Jekyll.
              pkgs.bundler
              pkgs.bundix
              pkgs.gnumake
              pkgs.gcc
            ];

            shellHook = ''
              ${config.pre-commit.installationScript}
            '';
          };
        };
      };
    };
}
