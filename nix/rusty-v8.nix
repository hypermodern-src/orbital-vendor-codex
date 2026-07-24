{
  fetchurl,
  lib,
  stdenv,
  cargoLockFile ? ../codex-rs/Cargo.lock,
}:
let
  cargoLock = builtins.fromTOML (builtins.readFile cargoLockFile);
  resolvedVersions = lib.unique (
    map (package: package.version) (builtins.filter (package: package.name == "v8") cargoLock.package)
  );
  version =
    if builtins.length resolvedVersions == 1 then
      builtins.head resolvedVersions
    else
      throw "expected exactly one v8 version in ${toString cargoLockFile}, found: ${builtins.toJSON resolvedVersions}";
  artifactHashesByVersion = {
    "149.2.0" = {
      "aarch64-apple-darwin" = "sha256-+rsuyNO6Wm3qY9uaNalg3FypheujLzQrm6Sqocc0sv4=";
      "aarch64-unknown-linux-gnu" = "sha256-+XdRJ8pk3MSjZi0BpSGizvuluY+DOUOog9hHc7Kv88U=";
      "x86_64-apple-darwin" = "sha256-eUlAo4o/ZrfvUqXwA8awlPdDrQQKZK+z082frUlADwc=";
      "x86_64-unknown-linux-gnu" = "sha256-iu2YY323533Iv7i7R1nsW95HLQv3lD9Y4OYqNQlFxVk=";
    };
  };
  hashes =
    artifactHashesByVersion.${version}
      or (throw "no rusty_v8 artifact hashes are pinned for v8 ${version}");
  target = stdenv.hostPlatform.rust.rustcTarget or stdenv.hostPlatform.config;
  hash = hashes.${target} or (throw "no rusty_v8 ${version} artifact is pinned for ${target}");
in
fetchurl {
  pname = "rusty-v8-archive";
  inherit hash version;
  url = "https://github.com/denoland/rusty_v8/releases/download/v${version}/librusty_v8_release_${target}.a.gz";
  passthru = {
    inherit target;
  };
}
