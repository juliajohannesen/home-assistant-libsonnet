(import "github.com/jsonnet-libs/k8s-libsonnet/1.35/main.libsonnet") + {
  local k = self,

  util:: {
    // Kausal k.libsonnet compat
    serviceFor(deployment, ignored_labels=[], nameFormat='%(container)s-%(port)s')::
      local container = k.core.v1.container;
      local service = k.core.v1.service;
      local servicePort = k.core.v1.servicePort;
      
      local ports = [
        servicePort.newNamed(
          name=(nameFormat % { container: c.name, port: port.name }),
          port=port.containerPort,
          targetPort=port.containerPort
        ) +
        if std.objectHas(port, 'protocol')
        then servicePort.withProtocol(port.protocol)
        else {}
        for c in deployment.spec.template.spec.containers
        for port in (c + container.withPortsMixin([])).ports
      ];
      local labels = {
        [x]: deployment.spec.template.metadata.labels[x]
        for x in std.objectFields(deployment.spec.template.metadata.labels)
        if std.count(ignored_labels, x) == 0
      };

      service.new(
        deployment.metadata.name,  // name
        labels,  // selector
        ports,
      ) +
      service.mixin.metadata.withLabels({ name: deployment.metadata.name }),   
  }
}
