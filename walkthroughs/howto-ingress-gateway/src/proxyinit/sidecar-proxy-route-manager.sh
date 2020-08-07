#!/bin/bash -e

#
# Start of configurable options
#

#APPMESH_START_ENABLED="0"
APPMESH_ENVOY_UID="1337"
APPMESH_ENVOY_EGRESS_PORT="15001"
APPMESH_ENVOY_LOCAL_FORWARD_PORT="10000"
APPMESH_EGRESS_IGNORED_IP="169.254.169.254,169.254.170.2" 

# Enable routing on the application start.
[ -z "$APPMESH_START_ENABLED" ] && APPMESH_START_ENABLED="0"

# Egress traffic from the Envoy UID will be ignored.
if [ -z "$APPMESH_ENVOY_UID" ]; then
    echo "Variable APPMESH_ENVOY_UID must be set."
    echo "Envoy must run under those IDs to be able to properly route its egress traffic."
    exit 1
fi

# Port numbers Application and Envoy are listening on.
if [ -z "$APPMESH_ENVOY_EGRESS_PORT" ]; then
    echo "APPMESH_ENVOY_EGRESS_PORT must be defined to forward traffic from the application to the proxy."
    exit 1
fi

# Port number the External proxy is listening on.
if [ -z "$APPMESH_ENVOY_LOCAL_FORWARD_PORT" ]; then
    echo "APPMESH_ENVOY_LOCAL_FORWARD_PORT must be defined to forward traffic destined to envoy egress port to the proxy."
    exit 1
fi

# Comma separated list of ports for which egress traffic will be ignored, we always refuse to route SSH traffic.
if [ -z "$APPMESH_EGRESS_IGNORED_PORTS" ]; then
    APPMESH_EGRESS_IGNORED_PORTS="22"
else
    APPMESH_EGRESS_IGNORED_PORTS="$APPMESH_EGRESS_IGNORED_PORTS,22"
fi

#
# End of configurable options
#

APPMESH_LOCAL_ROUTE_TABLE_ID="100"
APPMESH_PACKET_MARK="0x1e7700ce"

function initialize() {
    echo "=== Initializing ==="
    iptables -t nat -N APPMESH_EGRESS
    iptables -t nat -N APPMESH_LOCAL

    ip rule add fwmark "$APPMESH_PACKET_MARK" lookup $APPMESH_LOCAL_ROUTE_TABLE_ID
    ip route add local default dev lo table $APPMESH_LOCAL_ROUTE_TABLE_ID
}

function enable_egress_routing() {
    # Stuff to ignore
    [ -n "$APPMESH_ENVOY_UID" ] && \
        iptables -t nat -A APPMESH_EGRESS \
        -m owner --uid-owner $APPMESH_ENVOY_UID \
        -j RETURN

    [ -n "$APPMESH_EGRESS_IGNORED_PORTS" ] && \
        iptables -t nat -A APPMESH_EGRESS \
        -p tcp \
        -m multiport --dports "$APPMESH_EGRESS_IGNORED_PORTS" \
        -j RETURN

    [ -n "$APPMESH_EGRESS_IGNORED_IP" ] && \
        iptables -t nat -A APPMESH_EGRESS \
        -p tcp \
        -d "$APPMESH_EGRESS_IGNORED_IP" \
        -j RETURN

    # Redirect everything that is not ignored
    iptables -t nat -A APPMESH_EGRESS \
        -p tcp \
        -j REDIRECT --to $APPMESH_ENVOY_EGRESS_PORT

    # Apply APPMESH_EGRESS chain to non local traffic
    iptables -t nat -A OUTPUT \
        -p tcp \
        -m addrtype ! --dst-type LOCAL \
        -j APPMESH_EGRESS
}

function enable_local_redirect_routing() {
    # Ignore traffic that is not originated from Envoy
    [ -n "$APPMESH_ENVOY_UID" ] && \
        iptables -t nat -A APPMESH_LOCAL \
        -m owner ! --uid-owner $APPMESH_ENVOY_UID \
        -j RETURN

    # Route everything destined at the egress port of Envoy to the local forwarding port
    iptables -t nat -A APPMESH_LOCAL \
        -p tcp \
        -m multiport --dports "$APPMESH_ENVOY_EGRESS_PORT" \
        -j REDIRECT --to-port "$APPMESH_ENVOY_LOCAL_FORWARD_PORT"

    # Apply APPMESH_LOCAL chain to local traffic
    iptables -t nat -A OUTPUT \
        -p tcp \
        -m addrtype --dst-type LOCAL \
        -j APPMESH_LOCAL
}

function enable_routing() {
    echo "=== Enabling Egress routing ==="
    enable_egress_routing

    if [ -n "$APPMESH_ENVOY_LOCAL_FORWARD_PORT" ]; then
        echo "=== Enabling Local Routing ==="
        enable_local_redirect_routing
    fi
}

function disable_routing() {
    echo "=== Disabling routing ==="
    iptables -F
    iptables -F -t nat
}

function dump_status() {
    echo "=== Routing rules ==="
    ip rule
    echo "=== AppMesh routing table ==="
    ip route list table $APPMESH_LOCAL_ROUTE_TABLE_ID
    echo "=== iptables FORWARD table ==="
    iptables -L -v -n
    echo "=== iptables NAT table ==="
    iptables -t nat -L -v -n
}

function main_loop() {
    echo "=== Entering main loop ==="
    while read -p '> ' cmd; do
        case "$cmd" in
            "quit")
                break
                ;;
            "status")
                dump_status
                ;;
            "enable")
                enable_routing
                ;;
            "disable")
                disable_routing
                ;;
            *)
                echo "Available commands: quit, status, enable, disable"
                ;;
        esac
    done
}

function print_config() {
    echo "=== Input configuration ==="
    env | grep APPMESH_ || true
}

print_config

initialize

if [ "$APPMESH_START_ENABLED" == "1" ]; then
    enable_routing
fi

main_loop