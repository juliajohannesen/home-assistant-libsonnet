local k = import "./_k.libsonnet";

local deployment = k.apps.v1.deployment;
local container = k.core.v1.container;
local containerPort = k.core.v1.containerPort;
local service = k.core.v1.service;
local volume = k.core.v1.volume;
local volumeMount = k.core.v1.volumeMount;

{
  addons: (import "./addons/main.libsonnet"),

  new(host, image = "ghcr.io/home-assistant/home-assistant:stable"): {
    local root = self,

    _config+:: {
      homeAssistant:: {
        image:: image,
        node:: {
          selector:: null,
        },
        config:: { type:: "misconfigured" },
        ports:: {
          web:: 8123, 
        },
      }
    },

    homeAssistant:: {
      container:: container.new("home-assistant", root._config.homeAssistant.image)
        + container.withPorts([
          containerPort.newNamed(root._config.homeAssistant.ports.web, "web"),
        ])
        + container.withVolumeMounts([
          volumeMount.new("config", "/config"),
          volumeMount.new("localtime", "/etc/localtime", readOnly=true),
        ]),

      deployment:: deployment.new("home-assistant", replicas=1, containers=[root.homeAssistant.container])
        + deployment.spec.template.spec.withHostNetwork(true)
        + deployment.spec.template.spec.withDnsPolicy("ClusterFirstWithHostNet")
        + deployment.spec.template.spec.withVolumes([
          volume.fromHostPath("localtime", "/etc/localtime"),
          std.get({
            ["path"]: volume.fromHostPath("config", root._config.homeAssistant.config.path),
            ["pvc"]: volume.withName("config")
              + volume.persistentVolumeClaim.withClaimName(root._config.homeAssistant.config.pvc.metadata.name),
          }, root._config.homeAssistant.config.type, error "homeassistant config path misconfigured"),
        ])
        + local node = std.get(root._config.homeAssistant, "node");
          if node != null
          then deployment.spec.template.spec.withNodeSelector(node.selector)
          else {},

      service:: k.util.serviceFor(root.homeAssistant.deployment)
        + service.spec.withType("ClusterIP"),
      
      assert self.deployment.spec.replicas == 1 : "homeassistant can only run with a single replica- plesae do not try to override this",
    },

    homeAssistantDeployment: root.homeAssistant.deployment,

    homeAssistantSerivce: root.homeAssistant.service,
  },

  local withConfigMixin(mixin) = { _config+:: { homeAssistant+:: mixin } },

  withNodeSelector(nodeSelector):: withConfigMixin({
    node+:: { selector:: nodeSelector },
  }),

  withConfigPath(path):: withConfigMixin({
    config:: {
      type:: "path",
      path:: path,
    },
  }),

  withConfigPVC(pvc):: withConfigMixin({
    config:: {
      type:: "pvc",
      pvc:: pvc,
    },
  }),

  withContainerMixin(mixin):: {
    local root = self,
    homeAssistant+:: {
      container+:: if std.isFunction(mixin) then mixin(root) else mixin,
    },
  },

  withDeploymentMixin(mixin):: {
    local root = self,
    homeAssistant+:: {
      deployment+:: if std.isFunction(mixin) then mixin(root) else mixin,
    },
  },

  withBluetooth()::
    self.withContainerMixin(
      container.securityContext.capabilities.withAdd([
        "NET_ADMIN",
        "NET_RAW",
      ])
      + container.withVolumeMountsMixin([
        volumeMount.new("dbus", "/run/dbus", readOnly=true),
      ])
    )
    + self.withDeploymentMixin(deployment.spec.template.spec.withVolumesMixin([
      volume.fromHostPath("dbus", "/run/dbus"),
    ])),
}