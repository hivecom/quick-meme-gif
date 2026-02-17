{
  description = "Generates a meme type of gif from a url paramter";
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-25.05";
  };

  outputs = {
    self,
    nixpkgs,
  }: let
    supportedSystems = ["x86_64-linux"];
    forEachSystem = nixpkgs.lib.genAttrs supportedSystems;
    overlayList = [self.overlays.default];
    pkgsBySystem = forEachSystem (
      system:
        import nixpkgs {
          inherit system;
          overlays = overlayList;
        }
    );
  in {
    overlays.default = final: prev: {
      quick-meme-gif = final.callPackage ./package.nix {};
    };

    packages = forEachSystem (system: {
      default =
        pkgsBySystem.${system}.callPackage ./package.nix {};
    });
    devShells = forEachSystem (system: {
      default = pkgsBySystem.${system}.callPackage ./shell.nix {};
    });

    nixosModules.default = import ./nixos-modules/quick-meme-gif-service.nix;
  };
}
