#!/usr/bin/env bash
set -euo pipefail

: "${RELEASE_NAME:=microservices}"
: "${NAMESPACE:=microservices}"

kubectl rollout status "deployment/${RELEASE_NAME}-api" -n "$NAMESPACE" --timeout=5m
kubectl rollout status "deployment/${RELEASE_NAME}-books" -n "$NAMESPACE" --timeout=5m
kubectl rollout status "deployment/${RELEASE_NAME}-movies" -n "$NAMESPACE" --timeout=5m
kubectl get pods,svc -n "$NAMESPACE" -o wide

APP_IP="$(kubectl get svc api-service -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"
echo "Application URL: http://${APP_IP}/data"
echo "Run the HTTP test from the Simplon network."
