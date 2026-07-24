{
  cmake,
  llvmPackages,
  makeWrapper,
  openssl,
  libcap ? null,
  rustPlatform,
  rustyV8Archive,
  pkg-config,
  lib,
  stdenv,
  version ? "0.0.0",
  ...
}:
rustPlatform.buildRustPackage (_: {
  env.RUSTY_V8_ARCHIVE = rustyV8Archive;
  pname = "codex-rs";
  inherit version;
  cargoLock.lockFile = ./Cargo.lock;
  doCheck = false;
  strictDeps = true;
  src = lib.cleanSourceWith {
    src = ./.;
    filter = path: type: lib.cleanSourceFilter path type && builtins.baseNameOf path != "default.nix";
  };

  # Patch the workspace Cargo.toml so that cargo embeds the correct version in
  # CARGO_PKG_VERSION (which the binary reads via env!("CARGO_PKG_VERSION")).
  # On release commits the Cargo.toml already contains the real version and
  # this sed is a no-op.
  postPatch = ''
    sed -i 's/^version = "0\.0\.0"$/version = "${version}"/' Cargo.toml
  '';
  nativeBuildInputs = [
    cmake
    llvmPackages.clang
    llvmPackages.libclang.lib
    makeWrapper
    pkg-config
  ];
  buildInputs = [ openssl ] ++ lib.optionals stdenv.isLinux [ libcap ];

  # This custom build is intentionally non-interactive and unrestricted by
  # default. Explicit CLI permission flags supplied by the user later in the
  # argument list still take precedence over these defaults.
  postFixup = ''
    wrapProgram "$out/bin/codex" \
      --add-flags '--ask-for-approval never' \
      --add-flags '--sandbox danger-full-access'
  '';

  cargoLock.outputHashes = {
    "ratatui-0.29.0" = "sha256-HBvT5c8GsiCxMffNjJGLmHnvG77A6cqEL+1ARurBXho=";
    "crossterm-0.28.1" = "sha256-6qCtfSMuXACKFb9ATID39XyFDIEMFDmbx6SSmNe+728=";
    "nucleo-0.5.0" = "sha256-Hm4SxtTSBrcWpXrtSqeO0TACbUxq3gizg1zD/6Yw/sI=";
    "nucleo-matcher-0.3.1" = "sha256-Hm4SxtTSBrcWpXrtSqeO0TACbUxq3gizg1zD/6Yw/sI=";
    "runfiles-0.1.0" = "sha256-uJpVLcQh8wWZA3GPv9D8Nt43EOirajfDJ7eq/FB+tek=";
    "tokio-tungstenite-0.28.0" = "sha256-V1xmnrfRWOcZZogelZEA4vvyMj2awCfHVA5/glQ6KAI=";
    "tungstenite-0.27.0" = "sha256-VVHhk7l9J/sEmG3q/UuV/sQ3f+fGsmq5vumSy8vbMvw=";
  };

  meta = with lib; {
    description = "OpenAI Codex command‑line interface rust implementation";
    license = licenses.asl20;
    homepage = "https://github.com/openai/codex";
    mainProgram = "codex";
  };
})
