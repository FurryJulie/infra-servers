{ name, config, lib, pkgs, modulesPath, ... }:

{
  imports = [ ];

  systemd.timers.zfs-pvc-labels = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
        OnCalendar = "*-*-* *:00:00";
        Unit = "zfs-pvc-labels.service";
    };
    before = ["sanoid.service"];
  };
  # zfs list -r -o 'name,used,k8s:namespace,k8s:name' zroot/data/k8s-pv
  systemd.services.zfs-pvc-labels = {
    script = ''
      #!/usr/bin/env bash
      set -o errexit -o nounset -o pipefail
      IFS=$'\n\t\v'

      zfs=${pkgs.zfs}/bin/zfs
      jq=${pkgs.jq}/bin/jq
      k3s=${pkgs.k3s}/bin/k3s

      for dataset in $($zfs get -rj -t fs k8s:volume zroot/data/k8s-pv | $jq -r '.datasets | to_entries[] | select(.value.properties."k8s:volume".value == "-") | .key'); do
          pvc_volume=$(cut -d/ -f4 <<< $dataset)
          if [[ -z "$pvc_volume" ]]; then continue; fi
          pvc_json=$($k3s kubectl get -A pvc -ojson | $jq ".items[] | select(.spec.volumeName==\"$pvc_volume\")")
          if [[ -z "$pvc_json" ]]; then continue; fi
          pvc_namespace=$($jq -r '.metadata.namespace' <<< $pvc_json)
          pvc_name=$($jq -r '.metadata.name' <<< $pvc_json)

          echo "pvc $pvc_volume -> $pvc_namespace::$pvc_name"
          $zfs set "k8s:name=$pvc_name" "k8s:namespace=$pvc_namespace" "k8s:volume=$pvc_volume" $dataset
      done
    '';
    serviceConfig = {
      Type = "oneshot";
    };
  };

  services.sanoid = {
    enable = true;
    interval = "*-*-* *:00:00";

    datasets = {
        "zroot/data" = {
            autosnap = true;
            autoprune = true;
            recursive = true;

            hourly = 48;
            daily = 7;
            monthly = 0;
            yearly = 0;
        };
    };
  };

  # `zfs mount -a` needs to run on the remote host for this command to
  # consider itself successful, even though all data was transferred.
  services.syncoid = {
    enable = true;
    interval = "*-*-* *:00:00";
    commands = {
      "zroot/data" = {
        target = "pawhost-test@192.168.193.92:hot-1/replicas/test.pawhost.fluufff.org/data";
        recursive = true;
      };
    };
    commonArgs = [
      "--no-sync-snap"
      "--sshport=666"
      "--sendoptions=p"
    ];
    sshKey = /data/syncoid/syncoid.key;
    service = {
      serviceConfig = {
        BindReadOnlyPaths = [
          "/data/syncoid"
        ];
      };
    };
  };

  services.openssh = {
    knownHosts = {
      "192.168.193.92".publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBJQzfnDaiVk1fyA+FA6LyKf5Y4N/AsFs+Lc3q8rIwxt";
    };
  };
}