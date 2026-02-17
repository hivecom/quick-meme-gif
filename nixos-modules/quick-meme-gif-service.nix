{
  modulesPath,
  config,
  pkgs,
  lib,
  ...
}:
with lib; let
  cfg = config.services.quick-meme-gif;
in {
  options = {
    services.quick-meme-gif = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Whether to run quick-meme-gif.
        '';
      };
      package = mkOption {
        type = types.package;
        default = pkgs.callPackage ../package.nix {};
        description = "quick-meme-gif package";
      };

      port = mkOption {
        type = types.port;
        default = 4579;
        description = ''
          Port the API runs on.
        '';
      };

      fontPath = mkOption {
        type = types.str;
        default = "${pkgs.corefonts}/share/fonts/truetype/Impact.ttf";
        description = ''
          Path to the font file to use for images.
        '';
      };

      logLevel = mkOption {
        type = types.str;
        default = "debug";
        description = ''
          Rust log level: https://docs.rs/env_logger/latest/env_logger/#enabling-logging
        '';
      };

      nginx = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = ''
            Whether to enable nginx virtual host management.
            Further nginx configuration can be done by adapting <literal>services.nginx.virtualHosts.&lt;name&gt;</literal>.
            See <xref linkend="opt-services.nginx.virtualHosts"/> for further information.
          '';
        };
        virtualHost = mkOption {
          type = types.submodule (
            recursiveUpdate (import (modulesPath + "/services/web-servers/nginx/vhost-options.nix") {
              inherit config lib;
            }) {}
          );
          example = literalExpression ''
            {
              serverName = "jkbx.example.org";
              forceSSL = true;
              enableACME = true;
            }
          '';
          description = ''
            Nginx configuration can be done by adapting `services.nginx.virtualHosts.<name>`.
            See [](#opt-services.nginx.virtualHosts) for further information.
          '';
        };
      };
    };
  };

  config = mkIf cfg.enable {
    systemd.services.quick-meme-gif = {
      description = "Puts query text on a gif";
      wantedBy = ["multi-user.target"];
      after = ["network-online.target"];
      wants = ["network-online.target"];
      environment = {
        BIND_ADDRESS = "127.0.0.1:${builtins.toString cfg.port}";
        DATA_PATH = "/var/lib/quick-meme-gif/";
        FONT_PATH = cfg.fontPath;
        RUST_LOG = cfg.logLevel;
        RUST_BACKTRACE = "1";
      };
      serviceConfig = {
        DynamicUser = true;
        StateDirectory = "quick-meme-gif";
        ExecStart = "${lib.getExe cfg.package}";
        Restart = "always";
        RestartSec = 30;

        # Hardening - look into adding more
        CapabilityBoundingSet = [""];
        AmbientCapabilities = [""];
        NoNewPrivileges = true;
        ProtectSystem = "full";
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        PrivateTmp = true;
        LockPersonality = true;
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_UNIX"
        ];
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
      };
    };

    services.nginx = mkIf cfg.nginx.enable {
      enable = true;
      virtualHosts.${cfg.nginx.virtualHost.serverName} = lib.mkMerge [
        cfg.nginx.virtualHost
        {
          locations."/" = {
            proxyPass = "http://127.0.0.1:${builtins.toString cfg.port}";
            recommendedProxySettings = true;
          };
        }
      ];
    };
  };
}
