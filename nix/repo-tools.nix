{
  autoPatchelfHook,
  fetchurl,
  lib,
  stdenv,
  stdenvNoCC,
  bazelVersionFile ? ../.bazelversion,
  buildifierManifestFile ? ../tools/buildifier,
}:
let
  bazelVersion = lib.removeSuffix "\n" (builtins.readFile bazelVersionFile);
  bazelArtifactsByVersion = {
    "9.0.0" = {
      "aarch64-darwin" = {
        hash = "sha256-LDzOVIpLapeipSZ3Ehh7eEtScUxKKwYT5zhrFWadeDw=";
        suffix = "darwin-arm64";
      };
      "aarch64-linux" = {
        hash = "sha256-yrI8WdPTnF5TgvEs0Ra0dEWv3/mBNRbBiuPuiDazA38=";
        suffix = "linux-arm64";
      };
      "x86_64-darwin" = {
        hash = "sha256-qn5fw2Tqq6f08nHb+MFBcqVDP2Y8ymsTAyXfS2Vps/A=";
        suffix = "darwin-x86_64";
      };
      "x86_64-linux" = {
        hash = "sha256-xEqT8lOYxo+QT6HRm2HTId5sDS8J3KN117wNyblChAM=";
        suffix = "linux-x86_64";
      };
    };
  };
  bazelArtifacts =
    bazelArtifactsByVersion.${bazelVersion}
      or (throw "no Bazel artifact hashes are pinned for ${bazelVersion}");
  bazelArtifact =
    bazelArtifacts.${stdenv.hostPlatform.system}
      or (throw "no Bazel ${bazelVersion} artifact is pinned for ${stdenv.hostPlatform.system}");

  buildifierManifest = builtins.fromJSON (
    lib.removePrefix "#!/usr/bin/env dotslash\n\n" (builtins.readFile buildifierManifestFile)
  );
  buildifierPlatforms = {
    "aarch64-darwin" = "macos-aarch64";
    "aarch64-linux" = "linux-aarch64";
    "x86_64-darwin" = "macos-x86_64";
    "x86_64-linux" = "linux-x86_64";
  };
  buildifierPlatformName =
    buildifierPlatforms.${stdenv.hostPlatform.system}
      or (throw "tools/buildifier has no platform mapping for ${stdenv.hostPlatform.system}");
  buildifierArtifact = buildifierManifest.platforms.${buildifierPlatformName};
  buildifierProvider = builtins.head buildifierArtifact.providers;
  buildifierVersionMatch = builtins.match ".*/download/v([^/]+)/.*" buildifierProvider.url;
  buildifierVersion =
    if buildifierVersionMatch == null then
      throw "could not determine the Buildifier version from ${buildifierProvider.url}"
    else
      builtins.head buildifierVersionMatch;
in
{
  bazel = stdenvNoCC.mkDerivation {
    pname = "bazel";
    version = bazelVersion;
    src = fetchurl {
      inherit (bazelArtifact) hash;
      url = "https://releases.bazel.build/${bazelVersion}/release/bazel-${bazelVersion}-${bazelArtifact.suffix}";
    };
    dontUnpack = true;
    # Bazel is an ELF executable with an appended ZIP payload. GNU strip
    # discards that payload and leaves an unusable launcher.
    dontStrip = true;
    nativeBuildInputs = lib.optionals stdenv.isLinux [ autoPatchelfHook ];
    buildInputs = lib.optionals stdenv.isLinux [ stdenv.cc.cc.lib ];
    installPhase = ''
      runHook preInstall
      install -Dm755 "$src" "$out/bin/bazel"
      runHook postInstall
    '';
    meta = {
      description = "Bazel build tool pinned by .bazelversion";
      homepage = "https://bazel.build/";
      license = lib.licenses.asl20;
      mainProgram = "bazel";
      platforms = builtins.attrNames buildifierPlatforms;
    };
  };

  buildifier = stdenvNoCC.mkDerivation {
    pname = buildifierManifest.name;
    version = buildifierVersion;
    src = fetchurl {
      hash = builtins.convertHash {
        hash = buildifierArtifact.digest;
        hashAlgo = buildifierArtifact.hash;
        toHashFormat = "sri";
      };
      inherit (buildifierProvider) url;
    };
    dontUnpack = true;
    installPhase = ''
      runHook preInstall
      install -Dm755 "$src" "$out/bin/buildifier"
      runHook postInstall
    '';
    meta = {
      description = "Bazel BUILD file formatter pinned by tools/buildifier";
      homepage = "https://github.com/bazelbuild/buildtools";
      license = lib.licenses.asl20;
      mainProgram = "buildifier";
      platforms = builtins.attrNames buildifierPlatforms;
    };
  };
}
