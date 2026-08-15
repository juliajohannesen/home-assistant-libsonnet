local k = import "../_k.libsonnet";
local utils = import "../_utils.libsonnet";

local container = k.core.v1.container;
local containerPort = k.core.v1.containerPort;
local deployment = k.apps.v1.deployment;
local volume = k.core.v1.volume;
local volumeMount = k.core.v1.volumeMount;

{
  new(image = "ghcr.io/home-assistant-libs/python-matter-server:stable"): {
    local root = self,

    _config+:: {
      matter+:: {
        image:: image,
        node:: {
          selector:: null,
        },
        data:: { type:: "misconfigured" },
      },
    },

    matter+: {
      container+:: container.new("matter", root._config.matter.image)
        + container.securityContext.seccompProfile.withType("Unconfined")
        + container.securityContext.appArmorProfile.withType("Unconfined")
        + container.withPorts([
          containerPort.newNamed(5580, "websocket"),
        ])
        + container.withVolumeMounts([
          volumeMount.new("data", "/opt/matter-server"),
          volumeMount.new("dbus", "/run/dbus", readOnly=true),
        ]),
      
      deployment: deployment.new("matter")
        + deployment.spec.template.spec.withHostNetwork(true)
        + deployment.spec.template.spec.withContainers([ root.matter.container ])
        + deployment.spec.template.spec.withVolumes([
          volume.fromHostPath("dbus", "/run/dbus"),
          std.get({
            ["path"]: volume.fromHostPath("data", root._config.matter.data.path),
            ["pvc"]: volume.fromPersistentVolumeClaim("data", root._config.matter.data.pvc.metadata.name),
          }, root._config.matter.data.type, error "matter data volume misconfigured"),
        ])
        + if root._config.matter.node != null
          then deployment.spec.template.spec.withNodeSelector(root._config.matter.node.selector)
          else {},

      service: k.util.serviceFor(root.matter.deployment),
    },
  },

  local withConfigMixin(mixin) = {
    local root = self,
    _config+:: {
      matter+:: utils.provideRoot(root, mixin),
    },
  },

  withNodeSelector(selector): withConfigMixin({ node+:: { selector:: selector } }),

  withDataPath(path):: withConfigMixin({
    data:: { type:: "path", path:: path },
  }),
  withDataPVC(pvc):: withConfigMixin({
    data:: { type:: "pvc", pvc:: pvc },
  }),

  withContainerMixin(mixin): {
    local root = self,
    matter+: {
      container+:: utils.provideRoot(root, mixin),
    },
  },

  withDeploymentMixin(mixin): {
    local root = self,
    matter+: {
      deployment+: utils.provideRoot(root, mixin),
    },
  },
}