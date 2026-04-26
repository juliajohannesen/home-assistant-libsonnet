local utils = import "../../_utils.libsonnet";

// TODO: Make some kind of yaml-schema generator like jsonnet-libs/k8s
{
  local ffmpeg = {
    local with(x) = { ffmpeg+: x },
    withGlobalArgs(args): with({ global_args: args }),
    withHWAccelArgs(args): with({ global_args: args }),
    withInputArgs(args): with({ input_args: args }),
    withOutputArgs(args): with({ output_args: args }),
  },
  local retain = {
    local with(x) = { retain+: x },
    withDays(days): with({ days: days }),
    withMode(mode): with({ mode: mode }),
  },
  local alerts = {
    local with(x) = { alerts+: x },
    withPaddingBefore(before): with({ pre_capture: before }),
    withPaddingAfter(after): with({ post_capture: after }),
    withRetention(retention): retention,
  },
  local detections = {
    local with(x) = { detections+: x },
    withPaddingBefore(before): with({ pre_capture: before }),
    withPaddingAfter(after): with({ post_capture: after }),
    withRetention(retention): retention,
  },

  camera: {
    ffmpeg: ffmpeg {
      input: std.objectRemoveKey(ffmpeg, "withOutputArgs") + {
        new(path): self.withPath(path),
        withPath(path): { path: path },
        withRoles(roles): { roles: utils.toArray(roles) },
        withRolesMixin(roles): { roles+: utils.toArray(roles) },
      },

      local with(x) = { ffmpeg+: x },
      withPath(path): with({ path: path }),
      withRoles(roles): with({ roles: utils.toArray(roles) }),
      withRolesMixin(roles): with({ roles+: utils.toArray(roles) }),
      withInputs(inputs): with({ inputs: utils.toArray(inputs) }),
      withInputsMixin(inputs): with({ inputs+: utils.toArray(inputs) }),
    },

    new(name): { _name:: name },

    withEnabled(enabled): { enabled: true },
    withType(type): { type: type },
    withBestImageTimeout(timeout): { best_image_timeout: timeout },
    withWebUIURL(url): { webui_url: url },
  },

  detect: {
    stationary: {
      maxFrames: {
        local with(x) = { detect+: { stationary+: { max_frames+: x } } },
        withDefault(frames): with({ default: frames }),
        withObjects(objects): with({ objects: objects }),
        withObjectsMixin(objects): with({ objects+: objects }),
      },
      local with(x) = { detect+: { stationary+: x } },
      withInterval(interval): with({ interval: interval }),
      withThreshold(threshold): with({ threshold: threshold }),
    },
    local with(x) = { detect+: x },
    withEnabled(enabled): with({ enabled: enabled }),
    withWidth(width): with({ width: width }),
    withHeight(height): with({ height: height }),
    withFps(fps): with({ fps: fps }),
    withMaxDisappeared(n): with({ max_disappeared: n }),
  },

  detector: {
    new(name, type): { _name:: name } + self.withType(type),
    withType(type): { type: type },
    withDevice(device): { device: device },
  },
  
  ffmpeg: ffmpeg {
    local with(x) = { ffmpeg+: x },
    withPath(path): with({ path: path }),
    withRetryInterval(retryInterval): with({ retry_interval: 10 }),
    withAppleCompatibility(appleCompatibility): with({ apple_compatible: 10 }),
    withGPU(index): with({ gpu: index }),
  },

  model: {
    local with(x) = { model+: x },
    withType(type): with({ type: type }),
    withInput(input): with({
      width: input.width,
      height: input.height,
      input_pixel_format: if std.objectHas(input, "pixelFormat") then input.pixelFormat,
      input_tensor: if std.objectHas(input, "tensor") then input.tensor,
      input_dtype: if std.objectHas(input, "dtype") then input.dtype,
    }),
    withPaths(paths): with({
      path: paths.model,
    } + if std.objectHas(paths, "labelMap") then { labelmap_path: paths.labelMap } else {}),
    withLabelMap(labelMap): with({ labelmap: labelMap }),
    withAttributesMap(attributesMap): with({ attributes_map: attributesMap }),
  },

  objects: {
    filter: {
      new(subject): { _subject:: subject },
      withMinArea(minArea): { min_area: minArea },
      withMaxArea(maxArea): { max_area: maxArea },
      withMinRatio(minRatio): { min_ratio: minRatio },
      withMaxRatio(maxRatio): { max_ratio: maxRatio },
      withMinScore(minScore): { min_score: minScore },
      withMask(mask): {
        mask:
          if std.isArray(mask)
          then std.join(",", mask)
          else mask,
      },
      withThreshold(threshold): { threshold: threshold },
    },

    withFilters(filters): {
      objects+: {
        _filters:: utils.toArray(filters),
        filters: { [filter._subject]: filter for filter in self._filters },
      }
    },
    withFiltersMixin(mixin): {
      objects+: {
        _filters+:: utils.toArray(mixin),
        filters: { [filter._subject]: filter for filter in self._filters },
      }
    },
    
    withTracked(subjects): { objects+: { track: utils.toArray(subjects) } },
    withTrackedMixin(subjects): { objects+: { track+: utils.toArray(subjects) } },
    
    withMask(mask): {
      mask:
        if std.isArray(mask)
        then std.join(",", mask)
        else mask,
    },
  },

  review: {
    alerts: {
      local with(x) = { review+: { alerts+: x } },
      withLabels(labels): with({ labels: utils.toArray(labels) }),
      withLabelsMixin(labels): with({ labels+: utils.toArray(labels) }),
      withRequiredZones(zones): with({ required_zones: utils.toArray(zones) }),
      withRequiredZonesMixin(zones): with({ required_zones+: utils.toArray(zones) }),
    },
    detections: {
      local with(x) = { review+: { detections+: x } },
      withLabels(labels): with({ labels: utils.toArray(labels) }),
      withLabelsMixin(labels): with({ labels+: utils.toArray(labels) }),
      withRequiredZones(zones): with({ required_zones: utils.toArray(zones) }),
      withRequiredZonesMixin(zones): with({ required_zones+: utils.toArray(zones) }),
    },
  },

  record: {
    continuous: {
      local with(x) = { record+: { continuous+: x } },
      withDays(days): with({ days: days }),
    },
    export: {
      local with(x) = { record+: { export+: x } },
      withTimelapseArgs(args): with({ timelapse_args: args }),
    },
    preview: {
      local with(x) = { record+: { preview+: x } },
      withQuality(quality): with({ quality: quality }),
    },
    alerts: {
      local with(x) = { record+: { alerts+: x } },
      withPaddingBefore(before): with({ pre_capture: before }),
      withPaddingAfter(after): with({ post_capture: after }),
      withRetention(retention): with({ retain+: retention }),
    },
    detections: {
      local with(x) = { record+: { detections+: x } },
      withPaddingBefore(before): with({ pre_capture: before }),
      withPaddingAfter(after): with({ post_capture: after }),
      withRetention(retention): with({ retain+: retention }),
    },
    motion: {
      local with(x) = { record+: { motion+: x } },
      withDays(days): with({ days: days }),
    },
    
    local with(x) = { record+: x },
    withEnabled(enabled): with({ enabled: enabled }),
    withExpireInterval(expireInterval): with({ expire_interval: 60 }),
    withSyncRecordings(syncRecordings): with({ sync_recordings: 60 }),
    withRetention(retention): with({ retain+: retention }),
  },

  new(root): self.withAuthEnabled(true)
    + self.withAutomaticDatabasePath(root)
    + self.withAutomaticDetectorAndModel(root)
    + self.withAutomaticMQTT(root)
    + self.objects.withTracked(["person"]),
  
  withAutomaticDatabasePath(root):
    local matchingVolumeMounts = std.filter(
      function(vm) vm.name == "state" && vm.mountPath == "/config",
      root.frigate.container.volumeMounts,
    );
    if std.length(matchingVolumeMounts) == 1
    then
      self.withDatabasePath(matchingVolumeMounts[0].mountPath + "/database/frigate.db")
    else
      error "state volume mount not found for frigate",
  withAutomaticDetectorAndModel(root):
    local gpu = root._config.frigate.node.gpu;
    std.get({
      amd:
        $.withDetectors($.detector.new(gpu, "onnx") + $.detector.withDevice("GPU"))
        + $.model.withPaths({
          model: "plus://a256e1c432c284afbdb4b5e86f0efe6a" // yolonas
        }),
      nvidia:
        $.withDetectors($.detector.new(gpu, "onnx") + $.detector.withDevice("GPU"))
        + $.model.withPaths({
          model: "plus://a256e1c432c284afbdb4b5e86f0efe6a" // yolonas
        }),
      intel:
        $.withDetectors($.detector.new(gpu, "openvino") + $.detector.withDevice("GPU"))
        + $.model.withPaths({
          model: "plus://a256e1c432c284afbdb4b5e86f0efe6a" // yolonas
        }),
    }, gpu, self.withDetectors([$.detector.new("cpu", "cpu")])),
  withAutomaticMQTT(root): {
    mqtt+: {
      local mqtt = std.get(root, "mqtt"),
      assert mqtt != null : "an mqtt addon must be provided for the frigate addon defaults",
      host: mqtt.service.metadata.name,
      port:
        local matchingPorts = std.filter(
          function(port) port.name == "mqtt",
          root.mqtt.container.ports,
        );
        if std.length(matchingPorts) == 1
        then
          matchingPorts[0].containerPort
        else
          error "unable to find the mqtt port for the supplied mqtt addon",
      user: "{FRIGATE_MQTT_USER}",
      password: "{FRIGATE_MQTT_PASSWORD}",
    },
  },

  withAuthEnabled(authEnabled):: {
    auth: {
      enabled: authEnabled,
      cookie_secure: true,  
    },
  },

  withMQTT(mqtt): { mqtt: mqtt },
  withMQTTMixin(mixin): { mqtt+: mixin },

  withCameras(cameras): {
    _cameras:: utils.toArray(cameras),
    cameras: { [camera._name]: camera for camera in self._cameras },
  },
  withCamerasMixin(mixin): {
    _cameras+:: utils.toArray(mixin),
    cameras: { [camera._name]: camera for camera in self._cameras },
  },

  withDatabasePath(path): { database+: { path: path } },

  withDetectors(detectors): {
    _detectors:: utils.toArray(detectors),
    detectors: { [detector._name]: detector for detector in self._detectors },
  },
  withDetectorsMixin(detectors): {
    _detectors+:: utils.toArray(detectors),
    detectors: { [detector._name]: detector for detector in self._detectors },
  },
}
