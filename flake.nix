{
  description = "Development Nix flake for OpenAI Codex CLI";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      rust-overlay,
      ...
    }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems f;

      # Read the version from the workspace Cargo.toml (the single source of
      # truth used by the release workflow).
      cargoToml = builtins.fromTOML (builtins.readFile ./codex-rs/Cargo.toml);
      cargoVersion = cargoToml.workspace.package.version;

      # When building from a release commit the Cargo.toml already carries the
      # real version (e.g. "0.101.0").  On the main branch it is the placeholder
      # "0.0.0", so we fall back to a dev version derived from the flake source.
      version = if cargoVersion != "0.0.0" then cargoVersion else "0.0.0-dev+${self.shortRev or "dirty"}";

      systemConfig = forAllSystems (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ rust-overlay.overlays.default ];
          };
          rustToolchains = import ./nix/rust-toolchain.nix {
            inherit (pkgs) lib;
            inherit pkgs;
            rustToolchainFile = ./codex-rs/rust-toolchain.toml;
          };
          repoTools = pkgs.callPackage ./nix/repo-tools.nix { };
          rustyV8Archive = pkgs.callPackage ./nix/rusty-v8.nix { };
          codexPackage = pkgs.callPackage ./codex-rs {
            inherit rustyV8Archive version;
            rustPlatform = rustToolchains.rustPlatform;
          };
          devShell = pkgs.callPackage ./nix/dev-shell.nix {
            inherit codexPackage repoTools rustyV8Archive;
            rustToolchain = rustToolchains.development;
          };
        in
        {
          inherit
            codexPackage
            devShell
            pkgs
            repoTools
            rustToolchains
            rustyV8Archive
            ;
        }
      );
    in
    {
      packages = forAllSystems (
        system:
        let
          inherit (systemConfig.${system}) codexPackage repoTools rustyV8Archive;
        in
        {
          bazel = repoTools.bazel;
          buildifier = repoTools.buildifier;
          codex-rs = codexPackage;
          default = codexPackage;
          rusty-v8-archive = rustyV8Archive;
        }
      );

      devShells = forAllSystems (system: {
        default = systemConfig.${system}.devShell;
      });

      apps = forAllSystems (
        system:
        let
          codexPackage = systemConfig.${system}.codexPackage;
          app = {
            type = "app";
            program = "${codexPackage}/bin/codex";
            meta.description = "OpenAI Codex CLI";
          };
        in
        {
          codex = app;
          default = app;
        }
      );

      checks = forAllSystems (system: {
        codex-rs = systemConfig.${system}.codexPackage;
        dev-shell = systemConfig.${system}.devShell;
      });

      formatter = forAllSystems (system: systemConfig.${system}.pkgs.nixfmt);
    };
}
