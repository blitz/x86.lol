# Adapted from:
#
# http://stesie.github.io/2016/08/nixos-github-pages-env

let
  sources = import ./nix/sources.nix;
  pkgs = import sources.nixpkgs {};

  jekyll_env = pkgs.bundlerEnv rec {
    name = "jekyll_env";
    gemfile = ./Gemfile;
    lockfile = ./Gemfile.lock;
    gemset = ./gemset.nix;
  };
in
pkgs.stdenv.mkDerivation rec {
  name = "jekyll_env";
  buildInputs = [ jekyll_env ];

  shellHook = ''
    exec ${jekyll_env}/bin/jekyll serve --watch
  '';
}
