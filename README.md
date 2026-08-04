# kube-microservices-cd

This repository selects the application version deployed to AKS.

The complete update process is documented in
[`docs/update-flow.md`](docs/update-flow.md).

1. Verify the ACR server, image SHA tag, and Simplon CIDR in
   `environments/production/values.yaml`.
2. Add the required Azure variables in GitLab.
3. Configure OIDC to connect to Azure without a stored secret.
4. Allow this identity to deploy to AKS.
5. Commit the new tag and run the manual `deploy_production` job.

## Repository content

- `chart/microservices`: Helm deployment chart;
- `environments/production/values.yaml`: deployed image and environment values;
- `scripts/deploy.sh`: runs the Helm deployment;
- `scripts/verify.sh`: checks the rollout and Kubernetes resources;
- `docs/update-flow.md`: explains updates from Go code to AKS.

Update flow: Go code -> CI -> ACR image -> new tag here -> CD -> AKS.

## Local validation

From WSL:

```bash
git status --short
git diff --check
bash -n scripts/deploy.sh
bash -n scripts/verify.sh

docker run --rm -v "$PWD:/work" -w /work alpine/helm:3.18.6 \
  lint chart/microservices \
  -f environments/production/values.yaml
```

The production values contain the ACR image, its immutable commit tag, and the
allowed Simplon public IP.
