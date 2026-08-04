# Deploy the application to AKS

This guide follows the order requested in the brief: learn and validate once
with the portal and local commands, then use GitLab CI/CD for normal updates.
CI and CD are required deliverables. Infrastructure automation is a bonus.

## 1. Verified recommendation

Use the Simplon training subscription with:

- resource group: `hmezouarRG`;
- region: `francecentral`;
- AKS name: `aks-hmezouar-prf2026`;
- AKS Standard tier;
- one `Standard_D2_v3` node with 2 vCPUs and 8 GB RAM;
- Azure CNI Overlay;
- Standard Load Balancer;
- ACR Basic.

`Standard_D2_v3` is the deployed size allowed by the effective Azure Policy. It
provides the required 2 vCPUs and 8 GB RAM. VM quota is shared and can change,
so always run preflight before recreation. Do not enable availability zones,
autoscaling, or a second node.

## 2. Create ACR manually

In the Azure portal:

1. Select the Simplon training subscription.
2. Open **Container registries** and select **Create**.
3. Select resource group `hmezouarRG`.
4. Use region `France Central`.
5. Choose a globally unique name such as `acrhmezouarprf2026`.
6. Select the `Basic` SKU.
7. Keep the admin user disabled.

Verify before continuing from WSL:

```bash
az account set --subscription "OCC_Toulouse_AdminCloud_190227_INTENSIF-PRF-2026"
az acr show -g hmezouarRG -n acrhmezouarprf2026 --output table
```

## 3. Create AKS manually

In the Azure portal:

1. Open **Kubernetes services** and create a cluster.
2. Select resource group `hmezouarRG` and region `France Central`.
3. Name it `aks-hmezouar-prf2026`.
4. Select the AKS `Standard` tier.
5. Configure one `Standard_D2_v3` node.
6. Do not select availability zones or autoscaling.
7. Select Azure CNI Overlay and the Standard Load Balancer.
8. Enable OIDC and Workload Identity.
9. Attach the ACR registry created in the previous step.

Verify the cluster:

```bash
az aks show -g hmezouarRG -n aks-hmezouar-prf2026 --output table
az aks get-credentials -g hmezouarRG -n aks-hmezouar-prf2026 --overwrite-existing
kubectl get nodes -o wide
```

If ACR was not attached in the portal:

```bash
az aks update -g hmezouarRG -n aks-hmezouar-prf2026 --attach-acr acrhmezouarprf2026
```

## 4. Build and push the first image manually

Start Docker Desktop first. Run these commands from repository 1 and use the
short commit SHA as the image tag.

```bash
cd ../kube-microservices-aks

ACR_NAME="acrhmezouarprf2026"
IMAGE_NAME="kube-microservices"
IMAGE_TAG="$(git rev-parse --short HEAD)"
ACR_SERVER="$(az acr show -n "$ACR_NAME" --query loginServer -o tsv)"

az acr login --name "$ACR_NAME"
docker build -t "$ACR_SERVER/$IMAGE_NAME:$IMAGE_TAG" .
docker push "$ACR_SERVER/$IMAGE_NAME:$IMAGE_TAG"
```

Verify the pushed tag:

```bash
az acr repository show-tags -n "$ACR_NAME" --repository "$IMAGE_NAME" --output table
```

## 5. Deploy and test manually

Open repository 2 and verify the Simplon public IP followed by `/32`.

```bash
cd ../kube-microservices-cd

SIMPLON_CIDR="93.93.43.119/32"

helm upgrade --install microservices chart/microservices \
  --namespace microservices --create-namespace \
  -f environments/production/values.yaml \
  --set-string global.image.repository="$ACR_SERVER/$IMAGE_NAME" \
  --set-string global.image.tag="$IMAGE_TAG" \
  --set-string api.service.loadBalancerSourceRanges[0]="$SIMPLON_CIDR" \
  --wait --timeout 5m
```

Verify Kubernetes before testing the URL:

```bash
kubectl get pods,svc -n microservices -o wide
kubectl rollout status deployment/microservices-api -n microservices
APP_IP="$(kubectl get svc api-service -n microservices -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"
curl "http://$APP_IP/data"
```

The URL must work from the Simplon office and be blocked from other public IP
addresses.

## 6. Configure GitLab CI

The application pipeline is in `.gitlab-ci.yml`. It tests the Go code and uses
`az acr build` to publish images tagged with `$CI_COMMIT_SHORT_SHA`.

Remaining configuration:

1. Create a Microsoft Entra application for the application repository.
2. Add a federated credential for the GitLab project and `main` branch.
3. Grant the required ACR role to this identity.
4. Add `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`, and
   `ACR_NAME` as GitLab variables.
5. Push a commit and verify that the pipeline creates the expected SHA tag.

Do not create or store an Azure client secret.

## 7. Create the CD repository

This is the CD repository. Configure its OIDC identity and Azure variables.
Verify the ACR server, image SHA tag, and Simplon CIDR in
`environments/production/values.yaml`.

The CD repository controls which image tag runs on AKS.

## 8. Application update flow

1. Change the Go code in the application repository.
2. Push the commit.
3. CI builds an image tagged with the commit SHA.
4. Change the image tag in the CD repository.
5. Push the CD change.
6. Run the manual `deploy_production` job.
7. Verify the pods and `/data`.

## 9. Optional infrastructure automation

The brief asks for a working manual deployment before automation. After that
validation, this optional bonus script can reproduce ACR and AKS:

```bash
cd ../kube-microservices-aks
pwsh -File ./scripts/aks-infra.ps1 -Action preflight
pwsh -File ./scripts/aks-infra.ps1 -Action create
pwsh -File ./scripts/aks-infra.ps1 -Action status
pwsh -File ./scripts/aks-infra.ps1 -Action credentials
pwsh -File ./scripts/aks-infra.ps1 -Action stop
pwsh -File ./scripts/aks-infra.ps1 -Action start
```

The optional infrastructure implementation remains in repository 1. It is
script-based automation, not Terraform IaC.

Guarded AKS deletion is available with:

```bash
pwsh -File ./scripts/aks-infra.ps1 -Action delete \
  -ConfirmDelete aks-hmezouar-prf2026
```

This target keeps ACR and its images.
