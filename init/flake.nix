{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
  inputs.disko.url = "github:nix-community/disko";
  inputs.disko.inputs.nixpkgs.follows = "nixpkgs";
  inputs.nixos-facter-modules.url = "github:numtide/nixos-facter-modules";

  outputs =
    {
      nixpkgs,
      disko,
      nixos-facter-modules,
      ...
    }:
      let
        hosts = [
          "pawhost-next"
          "test-vm"
          "test-vm-julie"
        ];
      in {
        nixosConfigurations =
          builtins.listToAttrs (map
            (name: {
              name = name;
              value = nixpkgs.lib.nixosSystem {
                system = "x86_64-linux";
                modules = [
                  disko.nixosModules.disko
                  ../hosts/${name}/init.nix
                ];
              };
            })
            hosts
          );
        
        system.stateVersion = "25.05";
      };

}
