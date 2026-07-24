{
  lib,
  pkgs,
  rustToolchainFile,
}:
let
  toolchainToml = builtins.fromTOML (builtins.readFile rustToolchainFile);
  toolchainSpec = toolchainToml.toolchain;
  channel = toolchainSpec.channel;
  channelPackages =
    pkgs.rust-bin.stable.${channel}
      or (throw "rust-overlay does not provide the pinned Rust toolchain ${channel}");
  configuredComponents = toolchainSpec.components or [ ];
  configuredTargets = toolchainSpec.targets or [ ];
  developmentProfile = toolchainSpec.profile or "default";
  developmentBase =
    channelPackages.${developmentProfile}
      or (throw "rust-overlay does not provide Rust profile ${developmentProfile} for ${channel}");
  development = developmentBase.override {
    extensions = lib.unique (configuredComponents ++ [ "rust-analyzer" ]);
    targets = configuredTargets;
  };
  build = channelPackages.minimal;
in
{
  inherit
    build
    channel
    development
    ;
  rustPlatform = pkgs.makeRustPlatform {
    cargo = build;
    rustc = build;
  };
}
