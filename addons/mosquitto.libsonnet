local k = import "../_k.libsonnet";
local utils = import "../_utils.libsonnet";

local deployment = k.apps.v1.deployment;
local configMap = k.core.v1.configMap;
local container = k.core.v1.container;
local containerPort = k.core.v1.containerPort;
local service = k.core.v1.service;
local volume = k.core.v1.volume;
local volumeMount = k.core.v1.volumeMount;

{
  config: {
    new(root):
      local authenticationMixin =
        local matchingVolumeMounts = std.filter(
          function(volumeMount) volumeMount.name == "data",
          root.mqtt.container.volumeMounts,
        );
        if std.length(matchingVolumeMounts) == 1
        then
          self.withAuthentication(matchingVolumeMounts[0].mountPath + "/passwd")
        else
          error "too many or too few data volume mounts set for mosquitto";
      local httpPortMixin =
        local matchingPorts = std.filter(
          function(port) port.name == "web",
          root.mqtt.container.ports,
        );
        if std.length(matchingPorts) == 1
        then
          self.withHTTPPort(matchingPorts[0].containerPort)
        else
          error "too many or too few http ports set for mosquitto";
      local mqttPortMixin =
        local matchingPorts = std.filter(
          function(port) port.name == "mqtt",
          root.mqtt.container.ports,
        );
        if std.length(matchingPorts) == 1
        then
          self.withMQTTPort(matchingPorts[0].containerPort)
        else
          error "too many or too few mqtt ports set for mosquitto";
      local persistenceMixin =
        local matchingVolumeMounts = std.filter(
          function(volumeMount) volumeMount.name == "data",
          root.mqtt.container.volumeMounts,
        );
        if std.length(matchingVolumeMounts) == 1
        then
          self.withPersistence(matchingVolumeMounts[0].mountPath)
        else
          error "too many or too few data volume mounts set for mosquitto";
      authenticationMixin
      + httpPortMixin
      + mqttPortMixin
      + persistenceMixin
      + self.withLogging(),
    
    withAuthentication(path): {
      mqtt+: {
        allow_anonymous: false,
        password_file: path,
      },
    },

    withAnonymousAuthentication(allowAnonymous): {
      mqtt+: {
        allow_anonymous: allowAnonymous,
      },
    },
    
    withMQTTPort(port): {
      mqtt+: {
        listener: port,
        protocol: "mqtt",
      },
    },

    withHTTPPort(port): {
      http_api+: {
        listener: port,
        protocol: "http_api",
        http_dir: "/usr/share/mosquitto/dashboard",
      },
    },
    
    withPersistence(path): {
      persistence+: {
        persistence: true,
        persistence_location: path,
      },
    },

    withLogging(): {
      logging+: {
        log_dest: "stdout",
        log_type: [
          "error",
          "warning",
          "notice",
        ],
      },
    },
  },

  new(image = "docker.io/eclipse-mosquitto:2"): {
    local root = self,

    _config+:: {
      mosquitto:: {
        image:: image,
        node:: {
          selector:: null,
        },
        config:: $.config.new(root),
        data:: { type:: "misconfigured" },
        ports:: {
          web:: 9883,
          mqtt:: 1883,
        },
      }
    },

    mqtt:: {
      configMap:: configMap.new("mosquitto-config", {
        local renderField = function(key, value)
          if std.isArray(value)
          then std.join("\n", std.map(function(v) "%s %s" % [key, std.toString(v)], value))
          else "%s %s" % [key, std.toString(value)],
        local renderSection = function(name, fields)
          local all = std.objectKeysValuesAll(fields);
          local ordered =
            std.filter(function(f) f.key == "listener", all)
            + std.filter(function(f) f.key != "listener", all);
          "# " + name + "\n"
          + std.join("\n", [
            renderField(f.key, f.value)
            for f in ordered
          ]),
        "mosquitto.conf": std.join("\n\n", [
          renderSection(section.key, section.value)
          for section in std.objectKeysValuesAll(root._config.mosquitto.config)
        ]),
      }),

      container:: container.new("mosquitto", root._config.mosquitto.image)
        + container.withPorts([
          containerPort.newNamed(root._config.mosquitto.ports.mqtt, "mqtt"),
          containerPort.newNamed(root._config.mosquitto.ports.web, "web"),
        ])
        + container.withVolumeMounts([
          volumeMount.new("config", "/mosquitto/config"),
          volumeMount.new("data", "/mosquitto/data"),
        ]),

      deployment:: deployment.new("mosquitto", replicas=1, containers=[root.mqtt.container])
        + deployment.spec.template.spec.withVolumes([
          volume.withName("config") + volume.configMap.withName("mosquitto-config"),
          std.get({
            ["path"]: volume.fromHostPath("data", root._config.mosquitto.data.path),
            ["pvc"]: volume.withName("data")
              + volume.persistentVolumeClaim.withClaimName(root._config.mosquitto.data.pvc.metadata.name),
          }, root._config.mosquitto.data.type, error "mosquitto data volume misconfigured"),
        ])
        + local nodeSelector = root._config.mosquitto.node.selector;
          if nodeSelector != null
          then deployment.spec.template.spec.withNodeSelector(nodeSelector)
          else {},

      service:: k.util.serviceFor(root.mqtt.deployment)
        + service.spec.withType("ClusterIP"),
    },

    mosquittoConfigMap: root.mqtt.configMap,
    mosquittoDeployment: root.mqtt.deployment,
    mosquittoService: root.mqtt.service,
  },

  local withConfigMixin(mixin) = { _config+:: { mosquitto+:: mixin } },

  withNodeSelector(nodeSelector):: withConfigMixin({
    node:: { selector:: nodeSelector },
  }),

  withConfig(config): withConfigMixin(function(root) {
    config:: utils.provideRoot(root, config),
  }),
  withConfigMixin(mixin): withConfigMixin(function(root) {
    config+:: utils.provideRoot(root, mixin),
  }),

  withDataPath(path):: withConfigMixin({
    data:: { type:: "path", path:: path },
  }),
  withDataPVC(pvc):: withConfigMixin({
    data:: { type:: "pvc", pvc:: pvc },
  }),

  withContainerMixin(mixin):: {
    local root = self,
    mqtt+:: { container+:: utils.provideRoot(root, mixin) },
  },
  withDeploymentMixin(mixin):: {
    local root = self,
    mqtt+:: { deployment+:: utils.provideRoot(root, mixin) },
  },
}
