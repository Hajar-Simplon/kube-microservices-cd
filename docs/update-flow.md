# Application update flow

This document explains how an application change moves from the application
repository to AKS.

## Repository responsibilities

### Repository 1: application and CI

The application repository contains the Go source code, Dockerfile, tests, and
GitLab CI pipeline. Each successful pipeline publishes an ACR image tagged with
the short Git commit SHA.

Example:

```text
acrhmezouarprf2026.azurecr.io/kube-microservices:23369542
```

### Repository 2: deployment and CD

This repository contains the Helm chart, production values, CD pipeline, and
deployment documentation. It controls the deployed version in
`environments/production/values.yaml`:

```yaml
global:
  image:
    repository: acrhmezouarprf2026.azurecr.io/kube-microservices
    tag: "23369542"
```

AKS is updated only when this tag changes and the CD pipeline runs.

## Update procedure

1. Modify the Go code in the application repository.
2. Run the tests locally when possible.
3. Commit and push the change.
4. The application CI pipeline tests the code.
5. CI builds the image and pushes it to ACR with the commit SHA tag.
6. Verify that the new tag exists in ACR.
7. Open the CD repository.
8. Replace `global.image.tag` with the new SHA in
   `environments/production/values.yaml`.
9. Commit and push the CD change.
10. The CD pipeline validates the Helm chart.
11. Start the manual `deploy_production` job.
12. CD connects to AKS with OIDC and runs `helm upgrade --install`.
13. Verify the rollout, pods, Service, public IP, and `/data` endpoint.

## Verification

```bash
kubectl rollout status deployment/microservices-api -n microservices
kubectl get pods,svc -n microservices -o wide
curl "http://<LOADBALANCER-IP>/data"
```

## Rollback

Set `global.image.tag` to a previous working SHA, commit the change, and run the
CD pipeline again. Do not deploy the mutable `latest` tag.
