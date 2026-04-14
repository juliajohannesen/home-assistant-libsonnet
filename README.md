# HomeAssistant Libsonnet
> Deploy HomeAssistant and its addons- without leaving Kubernetes.

This repository contains configuration for deploying HomeAssistant via
Kubernetes using [Jsonnet][jsonnet] and [Grafana Tanka][tanka].

At the moment, these libraries are rather opinionated, and centric to my setup.
As my setup expands, more addons will be supported out of the box- and
contributions are welcome!

## Example

Deploy HomeAssistant itself, with a Traefik `IngressRoute`:

```jsonnet
local k = import "k.libsonnet";
local tanka = import "github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet";
local meta = import "meta.libsonnet";
local homeAssistant = import "github.com/juliajohannesen/home-assistant-libsonnet/main.libsonnet";
local traefik = import "traefik/main.libsonnet";

local environment = tanka.environment;
local ingressRoute = traefik.v1alpha1.ingressRoute;
local ingressRouteService = ingressRoute.spec.routes.services;

environment.new("home-assistant", "home-assistant", meta.apiServer)
  + environment.withData(
    homeAssistant.new("home.insertdomain.name")
      + homeAssistant.withNodeSelector({ "kubernetes.io/hostname": "homelab" })
      + homeAssistant.withConfigPath("/srv/home-assistant/config")
      + homeAssistant.withBluetooth()
      + {
        local root = self,

        homeAssistant+:: {
          ingressRoute:: ingressRoute.new("home-assistant-ingress-route")
            + ingressRoute.spec.withEntryPoints([ "web", "websecure" ])
            + ingressRoute.spec.withTLS()
            + ingressRoute.spec.withRoutes([
              ingressRoute.spec.routes.withKind("Rule")
                + ingressRoute.spec.routes.withMatch("Host(`home.insertdomain.name`)")
                + ingressRoute.spec.routes.withServices([
                  ingressRouteService.withKind("Service")
                    + ingressRouteService.withName(root.homeAssistant.service.metadata.name)
                    + ingressRouteService.withPort(root._config.homeAssistant.ports.web),
                ])
            ]),
        },

        homeAssistantIngressRoute: root.homeAssistant.ingressRoute,
      }
  )
```

[jsonnet]: https://jsonnet.org
[tanka]: https://tanka.dev
