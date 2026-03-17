{ name, config, lib, pkgs, modulesPath, ... }: {
  imports = [];

  services.openssh = {
    enable = true;
    ports = [ 666 ];
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };
  services.fail2ban = {
    enable = true;
  };
  services.endlessh = {
    enable = true;
    port = 22;
  };

  networking.firewall.allowedTCPPorts = [ 22 666 ];
  networking.firewall.allowedUDPPorts = [ ];
  networking.firewall.enable = false;
}
