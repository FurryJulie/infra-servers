{ name, config, lib, pkgs, modulesPath, ... }:

let
  argocd-crds = pkgs.fetchFromGitHub {
    owner = "argoproj";
    repo = "argo-cd";
    rev = "v3.2.1";
    sha256 = "sha256-AkHGhRHd2ybGYdgy6rNGBdS5YaHZKL4M9oKdqPxWYO0=";
  };
in
{
  imports = [ ];

  environment.systemPackages = with pkgs; [
    kubernetes-helm
  ];

  services.k3s = {
    enable = true;
    role = "server";
    nodeName = name;

    # # $ zfs create -o mountpoint=/var/lib/rancher/k3s/agent/containerd/io.containerd.snapshotter.v1.zfs <zpool name>/containerd
    # extraFlags = [
    #   "--snapshotter=zfs"
    # ];

    disable = [
      "traefik" # we maintain our own version
    ];

    manifests = {
      crd-application.source = "${argocd-crds}/manifests/crds/application-crd.yaml";
      crd-applicationset.source = "${argocd-crds}/manifests/crds/applicationset-crd.yaml";
      crd-appproject.source = "${argocd-crds}/manifests/crds/appproject-crd.yaml";
    };

    autoDeployCharts.traefik2 = {
      repo = "https://traefik.github.io/charts";
      name = "traefik";
      version = "37.4.0";
      hash = "sha256-BIGagu9qqQ7ijloBJp5bRBQUnVhcO8k4tmr6ZNx4pZU=";
      targetNamespace = "traefik";
      createNamespace = true;

      values = {
        additionalArguments = [
        ];
        ingressRoute = {
          dashboard = {
            enabled = true;
            matchRule = "Host(`traefik.fluuffftest.fpsource.info`)";
            entryPoints = ["web"];
            middlewares = [{
              name = "google-oauth";
              namespace = "traefik";
            }];
          };
        };
        extraObjects = [
          {
            apiVersion = "traefik.io/v1alpha1";
            kind = "Middleware";
            metadata = {
              name = "google-oauth";
              namespace = "traefik";
            };
            spec = {
              forwardAuth = {
                address = "http://google-oauth.traefik";
                trustForwardHeader = true;
                authResponseHeaders = [
                  "X-Forwarded-User"
                ];
              };
            };
          }
          {
            apiVersion = "apps/v1";
            kind = "Deployment";
            metadata = {
              name = "google-oauth";
              namespace = "traefik";
            };
            spec = {
              replicas = 1;
              selector = {
                matchLabels = {
                  app = "google-oauth";
                };
              };
              template = {
                metadata = {
                  labels = {
                    app = "google-oauth";
                  };
                };
                spec = {
                  containers = [{
                    name = "traefik-forward-auth";
                    image = "thomseddon/traefik-forward-auth:2";
                    env = [
                      # These depend on `traefik-secret.yaml`
                      # being manually applied to the cluster.
                      {
                        name = "PROVIDERS_GOOGLE_CLIENT_ID";
                        valueFrom = {
                          secretKeyRef = {
                            name = "auth";
                            key = "clientID";
                          };
                        };
                      }
                      {
                        name = "PROVIDERS_GOOGLE_CLIENT_SECRET";
                        valueFrom = {
                          secretKeyRef = {
                            name = "auth";
                            key = "clientSecret";
                          };
                        };
                      }
                      {
                        name = "SECRET";
                        valueFrom = {
                          secretKeyRef = {
                            name = "auth";
                            key = "cookieSecret";
                          };
                        };
                      }
                      {
                        name = "INSECURE_COOKIE";
                        value = "true";
                      }
                    ];
                  }];
                };
              };
            };
          }
          {
            apiVersion = "v1";
            kind = "Service";
            metadata = {
              name = "google-oauth";
              namespace = "traefik";
            };
            spec = {
              ports = [{
                name = "http";
                targetPort = 4181;
                port = 80;
              }];
              selector = {
                app = "google-oauth";
              };
            };
          }
        ];
      };
    };

    autoDeployCharts.argocd = {
      repo = "https://argoproj.github.io/argo-helm";
      name = "argo-cd";
      version = "9.1.4";
      hash = "sha256-JUeUjNwtVo/87q8zk5efNLmN4+y/J+C/5WDEy8VnNUY=";
      targetNamespace = "argocd";
      createNamespace = true;
      values = {
        global = {
          domain = "argocd.fluuffftest.fpsource.info";
        };
        crds = {
          install = false;
        };
        configs = {
          params = {
            "server.insecure" = "true";
          };
          cm = {
            url = "https://argocd.fluuffftest.fpsource.info";
            "admin.enabled" = false;
            "dex.config" = ''
              connectors:
              - config:
                  issuer: https://accounts.google.com
                  # These depend on `argocd-secret.yaml`
                  # being manually applied to the cluster.
                  clientID: $oidc.google.clientID
                  clientSecret: $oidc.google.clientSecret
                  insecureSkipVerify: true
                  userIDKey: email
                  userNameKey: email
                type: oidc
                id: google
                name: Google
              '';
            # Backup config for use in case of Dex troubles.
            # "oidc.config" = ''
            #   name: Google
            #   issuer: https://accounts.google.com
            #   clientID: $oidc.google.clientID
            #   clientSecret: $oidc.google.clientSecret
            #   requestedScopes: ["openid", "profile", "email"]
            #   '';

          };
          rbac = {
            "policy.csv" = ''
              p, role:operator, applications, sync, *, allow
              p, role:operator, applications, get, *, allow
              p, role:operator, applicationsets, get, *, allow
              p, role:operator, projects, get, *, allow
              p, role:operator, clusters, get, *, allow
              p, role:operator, repositories, get, *, allow
              p, role:operator, logs, get, *, allow

              g, julieiraes@fluufff.org, role:admin
              '';
          };
          secret = {
            createSecret = false;
          };
        };
        server = {
          ingress = {
            enabled = true;
          };
        };
        extraObjects = [
          {
            apiVersion = "argoproj.io/v1alpha1";
            kind = "Application";
            metadata = {
              name = "infra";
              namespace = "argocd";
            };
            spec = {
              project = "default";

              source = {
                repoURL = "https://github.com/FurryJulie/infra-argocd.git";
                targetRevision = "dev";
                path = "applications";
              };

              destination = {
                server = "https://kubernetes.default.svc";
                namespace = "argocd";
              };

              syncPolicy = {
                automated = {
                  prune = true;
                  selfHeal = true;
                };
              };
            };
          }
        ];
      };
    };

    autoDeployCharts.openebs = {
      repo = "https://openebs.github.io/openebs";
      name = "openebs";
      version = "4.4.0";
      hash = "sha256-mrxD80vqkPh2NcBzDYz/b0I1WUp2GJirBmbdgSQB5cg=";
      targetNamespace = "openebs";
      createNamespace = true;
      values = {
        engines = {
          replicated = {
            mayastor = {
              enabled = false;
            };
          };
          local = {
            lvm = {
              enabled = false;
            };
          };
        };
        loki = {
          enabled = false;
        };
        minio = {
          enabled = false;
        };
        alloy = {
          enabled = false;
        };
        # localpv-provisioner = {
        #   # localpv = {
        #   #   enabled = false;
        #   # };
        # };
        zfs-localpv = {
          # crds = {
          #   csi = {
          #     volumeSnapshots = {
          #       enabled = true;
          #     }
          #   };
          # };
          zfs = {
            bin = "/run/current-system/sw/bin/zfs";
          };
        };
        # lvm-localpv = {
        #   crds = {
        #     enabled = false;
        #   }
        # };
      };
    };
  };
}
