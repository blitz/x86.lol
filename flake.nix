{
  description = "The x86.lol blog source";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"

        # Not actively tested, but should work:
        # "aarch64-linux"
      ];

      perSystem = { config, system, pkgs, ... }: {
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

        devShells.default = pkgs.mkShell {
          packages = [ config.packages.jekyll_env ];

          shellHook = ''
            exec jekyll serve --watch --drafts
          '';
        };
      };
    };
}
