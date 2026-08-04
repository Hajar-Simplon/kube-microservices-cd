#!/usr/bin/env bash
set -euo pipefail

: "${RELEASE_NAME:=microservices}"
: "${NAMESPACE:=microservices}"

helm upgrade --install "$RELEASE_NAME" chart/microservices \
  --namespace "$NAMESPACE" \
  --create-namespace \
  --values environments/production/values.yaml \
  --wait \
  --timeout 5m
