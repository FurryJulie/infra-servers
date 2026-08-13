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

  networking.firewall.allowedTCPPorts = [ 6443 ];

  services.k3s = {
    enable = true;
    role = "server";
    nodeName = name;
    extraFlags = [
      "--tls-san=${config.deployment.targetHost}"
    ];

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
      version = "39.0.5";
      hash = "sha256-LWl7boE85UG4Is7POi/2/LlzImDS+z56lzc4iqOb8vU=";
      targetNamespace = "traefik";
      createNamespace = true;

      values = {
        additionalArguments = [
          "--entryPoints.websecure.http.tls.certResolver=letsencrypt"
          "--certificatesresolvers.letsencrypt.acme.caServer=https://acme-v02.api.letsencrypt.org/directory"
          "--certificatesresolvers.letsencrypt.acme.email=it@fluufff.org"
          "--certificatesresolvers.letsencrypt.acme.httpChallenge.entryPoint=web"
          "--certificatesresolvers.letsencrypt.acme.storage=/data/acme.json"
        ];
        ports = {
          web = {
            http = {
              redirections = {
                entryPoint = {
                  to = "websecure";
                  scheme = "https";
                  permanent = false;
                };
              };
            };
          };
        };
        ingressRoute = {
          dashboard = {
            enabled = true;
            matchRule = "Host(`traefik.next.fluufff.org`)";
            entryPoints = ["websecure"];
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
          domain = "argocd.next.fluufff.org";
        };
        crds = {
          install = false;
        };
        configs = {
          params = {
            "server.insecure" = "true";
          };
          cm = {
            url = "https://argocd.next.fluufff.org";
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
              p, role:operator, applications, action/*, default/*, allow
              p, role:operator, applicationsets, get, *, allow
              p, role:operator, projects, get, *, allow
              p, role:operator, clusters, get, *, allow
              p, role:operator, repositories, get, *, allow
              p, role:operator, logs, get, *, allow

              g, it@fluufff.org, role:admin
              g, juravenator@fluufff.org, role:admin
              g, proko@fluufff.org, role:operator
              g, niki@fluufff.org, role:operator
              g, julieiraes@fluufff.org, role:operator
              g, quezler@fluufff.org, role:operator
              g, annelies@fluufff.org, role:operator
              g, snuggly.ghost@fluufff.org, role:operator
              g, jorden@fluufff.org, role:operator
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
                repoURL = "https://github.com/Fluufff/infra-argocd.git";
                targetRevision = "next";
                path = "applications";
              };

              destination = {
                server = "https://kubernetes.default.svc";
                namespace = "argocd";
              };

              syncPolicy = {
                automated = {
                  enabled = false;
                  prune = false;
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
