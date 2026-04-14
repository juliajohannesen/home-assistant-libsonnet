local k = import "../../_k.libsonnet";
local utils = import "../../_utils.libsonnet";

local deployment = k.apps.v1.deployment;
local configMap = k.core.v1.configMap;
local container = k.core.v1.container;
local containerPort = k.core.v1.containerPort;
local envVar = k.core.v1.envVar;
local service = k.core.v1.service;
local volume = k.core.v1.volume;
local volumeMount = k.core.v1.volumeMount;

{
  config: (import "./config.libsonnet"),

  new(host, image = "ghcr.io/blakeblackshear/frigate:stable"): {
    local root = self,

    _config+:: {
      frigate:: {
        host:: host,
        image:: image,
        node:: {
          selector:: null,
          gpu:: null,
        },
        ports:: {
          webanon:: 5000,
          web:: 8971,
          rtsp:: 8554,
          webrtc:: 8555,
        },
        config:: $.config.new(root),
        media:: { type:: "misconfigured" },
        state:: { type:: "misconfigured" },
      }
    },

    frigate:: {
      configMap:: configMap.new("frigate-config", {
        "config.yml": std.manifestYamlDoc(root._config.frigate.config, quote_keys=false),
      }),

      container:: container.new("frigate", root._config.frigate.image)
        + container.securityContext.capabilities.withAdd(["CAP_PERFMON"])
        + container.withPorts([
          containerPort.newNamed(root._config.frigate.ports.web, "web"),
          containerPort.newNamed(root._config.frigate.ports.webanon, "webanon"),
          containerPort.newNamed(root._config.frigate.ports.rtsp, "rtsp"),
          containerPort.newNamed(root._config.frigate.ports.webrtc, "webrtc-tcp"),
          containerPort.newNamedUDP(root._config.frigate.ports.webrtc, "webrtc-udp"),
        ])
        + container.withVolumeMounts([
          volumeMount.new("state", "/config"),
          volumeMount.new("config", "/etc/frigate"),
          volumeMount.new("media", "/media"),
          volumeMount.new("shm", "/dev/shm"),
        ])
        + container.withEnvMixin([
          envVar.new("CONFIG_FILE", "/etc/frigate/config.yml"),
        ])
        + local gpu = root._config.frigate.node.gpu;
          if gpu != null
          then
            local resource = ({
              amd: "amd.com/gpu",
              nvidia: "nvidia.com/gpu",
              intel: "gpu.intel.com/i915",
            })[gpu];
            container.resources.withLimits({ [resource]: 1 })
          else
            {},

      deployment:: deployment.new("frigate", replicas=1, containers=[root.frigate.container])
        + deployment.spec.template.spec.withVolumes([
          volume.withName("config") + volume.configMap.withName("frigate-config"),
          std.get({
            ["path"]: volume.fromHostPath("state", root._config.frigate.state.path),
            ["pvc"]: volume.withName("state")
              + volume.persistentVolumeClaim.withClaimName(root._config.frigate.state.pvc.metadata.name),
          }, root._config.frigate.state.type, error "frigate state volume misconfigured"),
          std.get({
            ["path"]: volume.fromHostPath("media", root._config.frigate.media.path),
            ["pvc"]: volume.withName("media")
              + volume.persistentVolumeClaim.withClaimName(root._config.frigate.media.pvc.metadata.name),
          }, root._config.frigate.media.type, error "frigate media volume misconfigured"),
          volume.withName("shm")
            + volume.emptyDir.withMedium("Memory")
            + volume.emptyDir.withSizeLimit("256Mi"),
        ])
        + local nodeSelector = root._config.frigate.node.selector;
          if nodeSelector != null
          then deployment.spec.template.spec.withNodeSelector(nodeSelector)
          else {}
        + local gpu = root._config.frigate.node.gpu;
          if gpu != null
          then
            local resource = ({
              amd: "amd.com/gpu",
              nvidia: "nvidia.com/gpu",
              intel: "gpu.intel.com/i915",
            })[gpu];
            deployment.spec.template.spec.withTolerationsMixin([
              { key: resource, operator: "Exists", effect: "NoSchedule" },
            ])
          else
            {},

      service:: k.util.serviceFor(root.frigate.deployment)
        + service.spec.withType("ClusterIP"),
    },

    frigateConfigMap: root.frigate.configMap,
    frigateDeployment: root.frigate.deployment,
    frigateService: root.frigate.service,
  },

  local withConfigMixin(mixin) = {
    local root = self,
    _config+:: { frigate+:: utils.provideRoot(root, mixin) },
  },

  withNodeSelector(nodeSelector): withConfigMixin({
    node+:: { selector:: nodeSelector },
  }),

  withAMDGPU(): withConfigMixin({ node+:: { gpu:: "amd" } }),
  withIntelGPU(): withConfigMixin({ node+:: { gpu:: "intel" } }),
  withNVIDIAGPU(): withConfigMixin({ node+:: { gpu:: "nvidia" } }),

  withConfig(config): withConfigMixin(function(root) {
    config:: utils.provideRoot(root, config),
  }),
  withConfigMixin(mixin): withConfigMixin(function(root) {
    config+:: utils.provideRoot(root, mixin),
  }),

  withStatePath(path): withConfigMixin({
    state:: { type:: "path", path:: path },
  }),
  withStatePVC(pvc): withConfigMixin({
    state:: { type:: "pvc", pvc:: pvc },
  }),

  withMediaPath(path): withConfigMixin({
    media:: { type:: "path", path:: path },
  }),
  withMediaPVC(pvc): withConfigMixin({
    media:: { type:: "pvc", pvc:: pvc },
  }),

  withContainerMixin(mixin): {
    local root = self,
    frigate+:: {
      container+:: utils.provideRoot(root, mixin),
    },
  },
  withDeploymentMixin(mixin): {
    local root = self,
    frigate+:: {
      deployment+:: utils.provideRoot(root, mixin),
    },
  },

  withMQTTSecret(secret):
    self.withContainerMixin(function(root) container.withEnvMixin(
      local secretProvided = utils.provideRoot(root, secret);
      [
        envVar.fromSecretRef("FRIGATE_MQTT_USER", secretProvided.metadata.name, "username")
          + envVar.valueFrom.secretKeyRef.withOptional(false),
        envVar.fromSecretRef("FRIGATE_MQTT_PASSWORD", secretProvided.metadata.name, "password")
          + envVar.valueFrom.secretKeyRef.withOptional(false),
      ])),

  withPlusSecret(secret):
    self.withContainerMixin(function(root) container.withEnvMixin([
      local secretProvided = utils.provideRoot(root, secret);
      envVar.fromSecretRef("PLUS_API_KEY", secretProvided.metadata.name, "apiKey")
        + envVar.valueFrom.secretKeyRef.withOptional(false),
    ])),
}
