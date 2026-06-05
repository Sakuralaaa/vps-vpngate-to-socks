#!/usr/bin/env sh
set -eu

# Patch a self-hosted Zeabur K3s deployment so OpenVPN can create tun0.
# Usage:
#   sh scripts/zeabur-k3s-tun-patch.sh [namespace] [deployment]
# If arguments are omitted, the script tries to find the first deployment whose
# image contains "vps-vpngate-to-socks".

NAMESPACE="${1:-${ZEABUR_NAMESPACE:-}}"
DEPLOYMENT="${2:-${ZEABUR_DEPLOYMENT:-}}"

if ! command -v kubectl >/dev/null 2>&1; then
  echo "kubectl is required on the VPS host." >&2
  exit 1
fi

if [ ! -c /dev/net/tun ]; then
  echo "/dev/net/tun does not exist on the host. Enable TUN/TAP on the VPS first." >&2
  exit 1
fi

if [ -z "$NAMESPACE" ] || [ -z "$DEPLOYMENT" ]; then
  FOUND="$(
    kubectl get deploy -A \
      -o jsonpath='{range .items[*]}{.metadata.namespace}{" "}{.metadata.name}{" "}{range .spec.template.spec.containers[*]}{.image}{" "}{end}{"\n"}{end}' |
      awk '/vps-vpngate-to-socks/ {print $1 " " $2; exit}'
  )"
  if [ -z "$FOUND" ]; then
    echo "Could not find a vps-vpngate-to-socks deployment. Pass namespace and deployment explicitly." >&2
    exit 1
  fi
  NAMESPACE="$(printf '%s' "$FOUND" | awk '{print $1}')"
  DEPLOYMENT="$(printf '%s' "$FOUND" | awk '{print $2}')"
fi

CONTAINER="$(
  kubectl -n "$NAMESPACE" get deploy "$DEPLOYMENT" \
    -o jsonpath='{.spec.template.spec.containers[0].name}'
)"

PATCH="$(
  cat <<EOF
{
  "spec": {
    "template": {
      "spec": {
        "containers": [
          {
            "name": "$CONTAINER",
            "securityContext": {
              "privileged": true,
              "allowPrivilegeEscalation": true,
              "capabilities": {
                "add": ["NET_ADMIN", "NET_RAW"]
              }
            },
            "volumeMounts": [
              {
                "name": "dev-net-tun",
                "mountPath": "/dev/net/tun"
              }
            ]
          }
        ],
        "volumes": [
          {
            "name": "dev-net-tun",
            "hostPath": {
              "path": "/dev/net/tun",
              "type": "CharDevice"
            }
          }
        ]
      }
    }
  }
}
EOF
)"

echo "Patching deployment $NAMESPACE/$DEPLOYMENT ..."
kubectl -n "$NAMESPACE" patch deployment "$DEPLOYMENT" --type=strategic -p "$PATCH"
kubectl -n "$NAMESPACE" rollout status "deployment/$DEPLOYMENT" --timeout=180s

POD="$(
  kubectl -n "$NAMESPACE" get pod \
    -l "zeabur_service_id=${DEPLOYMENT#service-}" \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true
)"
if [ -z "$POD" ]; then
  POD="$(
    kubectl -n "$NAMESPACE" get pod \
      -o jsonpath='{.items[0].metadata.name}'
  )"
fi

echo "Verifying /dev/net/tun inside pod $POD ..."
kubectl -n "$NAMESPACE" exec "$POD" -- sh -lc 'ls -l /dev/net/tun && grep CapEff /proc/1/status'
