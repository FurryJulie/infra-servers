{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [ ];

  systemd.timers.platyplus-main-gen-invoice = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5m";
      OnUnitActiveSec = "5m";
      Unit = "platyplus-main-gen-invoice.service";
    };
  };

  systemd.services.platyplus-main-gen-invoice = {
    script = ''
      #!/usr/bin/env bash
      set -o errexit -o nounset -o pipefail
      IFS=$'\n\t\v'
      ${pkgs.k3s}/bin/kubectl -n platyplus-main exec -it deploy/platyplus -- php index.php Cronjob action/SecretCronJob/invoice
    '';
    serviceConfig = {
      Type = "oneshot";
    };
  };

  systemd.timers.platyplus-next-clean-cart = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "1m";
      OnUnitActiveSec = "1m";
      Unit = "platyplus-next-clean-cart.service";
    };
  };

  systemd.services.platyplus-next-clean-cart = {
    script = ''
      #!/usr/bin/env bash
      set -o errexit -o nounset -o pipefail
      IFS=$'\n\t\v'
      ${pkgs.k3s}/bin/kubectl -n platyplus-next exec -it deploy/platyplus -- php index.php Cronjob action/SecretCronJob/clean
    '';
    serviceConfig = {
      Type = "oneshot";
    };
  };

  systemd.timers.platyplus-main-clean-cart = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "1m";
      OnUnitActiveSec = "1m";
      Unit = "platyplus-main-clean-cart.service";
    };
  };

  systemd.services.platyplus-main-clean-cart = {
    script = ''
      #!/usr/bin/env bash
      set -o errexit -o nounset -o pipefail
      IFS=$'\n\t\v'
      ${pkgs.k3s}/bin/kubectl -n platyplus-main exec -it deploy/platyplus -- php index.php Cronjob action/SecretCronJob/clean
    '';
    serviceConfig = {
      Type = "oneshot";
    };
  };

  systemd.timers.platyplus-next-send-reminder = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      OnBootSec = "1sec";
      Unit = "platyplus-next-send-reminder.service";
    };
  };

  systemd.services.platyplus-next-send-reminder = {
    script = ''
      #!/usr/bin/env bash
      set -o errexit -o nounset -o pipefail
      IFS=$'\n\t\v'
      ${pkgs.k3s}/bin/kubectl -n platyplus-next exec -it deploy/platyplus -- php index.php Cronjob action/SecretCronJob/account
    '';
    serviceConfig = {
      Type = "oneshot";
    };
  };

  systemd.timers.platyplus-main-send-reminder = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      OnBootSec = "1sec";
      Unit = "platyplus-main-send-reminder.service";
    };
  };

  systemd.services.platyplus-main-send-reminder = {
    script = ''
      #!/usr/bin/env bash
      set -o errexit -o nounset -o pipefail
      IFS=$'\n\t\v'
      ${pkgs.k3s}/bin/kubectl -n platyplus-main exec -it deploy/platyplus -- php index.php Cronjob action/SecretCronJob/account
    '';
    serviceConfig = {
      Type = "oneshot";
    };
  };

  systemd.timers.platyplus-next-sql-backup = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "1h";
      OnUnitActiveSec = "1h";
      Unit = "platyplus-next-sql-backup.service";
    };
  };

  systemd.services.platyplus-next-sql-backup = {
    script = ''
      #!/usr/bin/env bash
      set -o errexit -o nounset -o pipefail
      IFS=$'\n\t\v'
      ${pkgs.k3s}/bin/kubectl -n platyplus-next exec -it deploy/mariadb -- mariadb-dump -u root "-p$(${pkgs.k3s}/bin/kubectl -n platyplus-next get secret mariadb-admin -ojson | ${pkgs.jq}/bin/jq -r '.data.pass' | ${pkgs.coreutils-full}/bin/base64 -d)" --lock-tables fluufff > /data/platyplus/sql-backups/mariadb-dump-next-$(date "+%Y-%m-%d-%H-%M-%S").sql
    '';
    serviceConfig = {
      Type = "oneshot";
    };
  };

  systemd.timers.platyplus-main-sql-backup = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "1h";
      OnUnitActiveSec = "1h";
      Unit = "platyplus-main-sql-backup.service";
    };
  };

  # Restore using
  # kubectl -n platyplus-main exec -it deploy/mariadb -- mariadb -u root "-p$(kubectl -n platyplus-main get secret mariadb-admin -ojson | jq -r '.data.pass' | base64 -d)" fluufff < /data/platyplus/sql-backups/mariadb-dump-next-2026-03-29-07-47-27.sql
  systemd.services.platyplus-main-sql-backup = {
    script = ''
      #!/usr/bin/env bash
      set -o errexit -o nounset -o pipefail
      IFS=$'\n\t\v'
      ${pkgs.k3s}/bin/kubectl -n platyplus-main exec -it deploy/mariadb -- mariadb-dump -u root "-p$(${pkgs.k3s}/bin/kubectl -n platyplus-main get secret mariadb-admin -ojson | ${pkgs.jq}/bin/jq -r '.data.pass' | ${pkgs.coreutils-full}/bin/base64 -d)" --lock-tables fluufff > /data/platyplus/sql-backups/mariadb-dump-main-$(date "+%Y-%m-%d-%H-%M-%S").sql
    '';
    serviceConfig = {
      Type = "oneshot";
    };
  };
}