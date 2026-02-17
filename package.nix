{
  makeWrapper,
  pkg-config,
  cmake,
  glib,
  openssl,
  lib,
  rustPlatform,
}:
rustPlatform.buildRustPackage {
  pname = "quick-meme-gif";
  version = "0.1.0";
  cargoLock.lockFile = ./Cargo.lock;
  src = lib.cleanSource ./.;

  nativeBuildInputs = [makeWrapper pkg-config cmake];
  buildInputs = [
    glib
    openssl
  ];

  meta = {
    description = "Generates a meme type of gif from a url paramter";
    mainProgram = "quick-meme-gif";
    maintainers = with lib.maintainers; [jokler];
  };
}
