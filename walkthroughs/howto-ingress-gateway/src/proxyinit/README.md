# AWS AppMesh Gateway Envoy routing setup

Application traffic at the Ingress gateway is served by a standalone Envoy.
This does not require iptable rules to perform any traffic redirection. 
However, if we need to redirect local traffic between the Envoy ingress port
and the Envoy egress (self-redirect) port via an external proxy, this redirection
can be performed using these iptable rules.

This package includes a shell script that manages iptables redirection rules for 
local and egress traffic.

## Configuration options

Route management script is configured by passing environment variables to it.
Following is the list of available options:

- `APPMESH_START_ENABLED` [optional (default: 0)] - If set to 1, routing rules
    will be automatically enabled upon the script startup.
- `APPMESH_ENVOY_UID` [required (conditionally)] - Envoy UID for which traffic redirection will not be
    performed for Egress traffic but, will be performed for local traffic.
- `APPMESH_ENVOY_EGRESS_PORT` [required] - Envoy listening port for handling egress traffic.
- `APPMESH_ENVOY_LOCAL_FORWARD_PORT` [required] - Forwarding port where local routing rules will redirect traffic from Envoy.
- `APPMESH_EGRESS_IGNORED_PORTS` [optional (default: 22)] - Comma separated list of port number for which
    egress traffic will be ignored by the routing rules. Port 22 (SSH) is always
    added to the list.

## Run time control

Once started, route management script enters the main loop and listens to
commands on stdin. Following is the list of valid commands:

- `enable` - Enabled the routing rules.
- `disable` - Disable the routing rules.
- `status` - Print the routing status.
- `quit` - Stop the script. Routing rules will not be reset to their original
    state on exit.
