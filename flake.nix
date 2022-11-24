{
  description = "The x86.lol blog source";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, nixpkgs }: let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      jekyll_env = pkgs.bundlerEnv rec {
        name = "jekyll_env";
        gemfile = ./Gemfile;
        lockfile = ./Gemfile.lock;
        gemset = ./gemset.nix;
      };
  in {
    packages.x86_64-linux.default = pkgs.stdenv.mkDerivation {
      name = "x86-lol";

      src = ./.;
      nativeBuildInputs = [ jekyll_env ];

      dontConfigure = true;

      buildPhase = ''
        jekyll build
      '';

      installPhase = ''
        mkdir -p $out
        cp -r _site/* $out/
      '';
    };

    devShells.x86_64-linux.default = pkgs.mkShell {
      packages = [ jekyll_env ];

      shellHook = ''
        exec jekyll serve --watch --drafts
      '';
    };
  };
}
