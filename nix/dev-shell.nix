{
  codexPackage,
  pkgs,
  repoTools,
  rustToolchain,
  rustyV8Archive,
}:
pkgs.mkShell {
  name = "codex-rs-dev";

  # Keep native libraries and build tools aligned with the package derivation.
  inputsFrom = [ codexPackage ];

  packages =
    with pkgs;
    [
      cargo-insta
      cargo-nextest
      dotslash
      git
      jq
      just
      nixfmt
      nodejs_22
      pnpm
      python3
      ripgrep
      rustToolchain
      uv
    ]
    ++ [
      repoTools.bazel
      repoTools.buildifier
    ];

  RUSTY_V8_ARCHIVE = rustyV8Archive;
  LIBCLANG_PATH = "${pkgs.llvmPackages.libclang.lib}/lib";
  RUST_SRC_PATH = "${rustToolchain}/lib/rustlib/src/rust/library";
  shellHook = ''
    export CC="${pkgs.llvmPackages.clang}/bin/clang"
    export CXX="${pkgs.llvmPackages.clang}/bin/clang++"
  '';
}
