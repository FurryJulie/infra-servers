{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    colmena.url = "github:zhaofengli/colmena";
  };
  outputs = { nixpkgs, colmena, ... }: {
    colmenaHive = colmena.lib.makeHive {
      meta = {
        nixpkgs = import nixpkgs {
          system = "x86_64-linux";
          overlays = [];
        };
      };

      test-vm = ./hosts/test-vm;
      test-vm-julie = ./hosts/test-vm-julie;
      pawhost-next = ./hosts/pawhost-next;
    };


    # Allows running: nix run .#colmena
    packages.x86_64-linux.colmena = colmena.packages.x86_64-linux.colmena;
    packages.aarch64-darwin.colmena = colmena.packages.aarch64-darwin.colmena;

    # Optional dev shell: nix develop
    devShells.x86_64-linux.default =
      nixpkgs.legacyPackages.x86_64-linux.mkShell {
        packages = [ colmena.packages.x86_64-linux.colmena ];
      };

  };
}