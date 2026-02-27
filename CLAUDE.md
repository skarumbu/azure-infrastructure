# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Purpose

Azure Infrastructure as Code (IaC) project using **Azure Bicep** to deploy the "Quixotry" web application (quixotry.me). Manages cloud resources for a React frontend, a containerized Python API, and a serverless Python Functions API.

## Deployment Commands

### Deploy infrastructure (Bicep templates)
```bash
./deploy.sh
```
Optional env vars before running:
```bash
export SUBSCRIPTION_ID="your-subscription-id"
export CUSTOM_DOMAIN="https://www.quixotry.me/"
```

### Build and deploy APIs
```bash
./build-and-deploy-apis.sh
```
Requires: Azure CLI, Docker, Azure Functions Core Tools (`func` command).

### Deploy a specific Bicep module manually
```bash
az deployment group create \
  --resource-group my-website-prod-rg \
  --template-file modules/<module>.bicep
```

### Lint/validate Bicep files
```bash
az bicep build --file main.bicep
az bicep build --file modules/<module>.bicep
```

## Architecture Overview

**Deployment scope**: Subscription-level (`main.bicep` targets subscription scope, creates a resource group `my-website-{environment}-rg`, then deploys all modules into it).

**Resource creation order in `main.bicep`**:
1. Resource Group
2. Static Web App (`modules/staticwebapp.bicep`) — React frontend, auto-deploys from GitHub repo `skarumbu/my-website`
3. Container Registry (`modules/containerregistry.bicep`) — stores Docker images for containerized APIs
4. Container App Environment (`modules/containerappenvironment.bicep`) — shared managed environment with Log Analytics (30-day retention)
5. Momentum Finder API (`modules/momentumfinder.bicep`) — Python app on Container Apps, port 8000, scales 0–10 replicas
6. Digits API (`modules/digitsfunctions.bicep`) — Python 3.11 Azure Functions on Dynamic (Y1) plan, with a dedicated Storage Account

**External source repos** cloned at deploy time by `build-and-deploy-apis.sh`:
- Frontend: `github.com/skarumbu/my-website`
- Momentum Finder: `github.com/skarumbu/momentum_finder`
- Digits API: `github.com/skarumbu/digits`

## Deployed Services

| Service | URL |
|---------|-----|
| Frontend (primary) | `https://www.quixotry.me` |
| Frontend (SWA default) | `https://delightful-water-01503ef10.6.azurestaticapps.net` |
| Momentum Finder API | `https://momentum-finder-prod.blueplant-685bd8b6.centralus.azurecontainerapps.io` |
| Digits API | `https://digits-api-prod-hwbxtkz6lsfoq.azurewebsites.net/api/DigitsGetter` |

## Custom Domain (quixotry.me)

DNS is managed in **AWS Route53**. Records in the `quixotry.me` hosted zone:

| Type | Name | Value | Purpose |
|------|------|-------|---------|
| A (ALIAS) | `quixotry.me` | S3 bucket `quixotry.me` (us-east-1) | Apex → redirect to www |
| CNAME | `www` | `delightful-water-01503ef10.6.azurestaticapps.net` | Routes to Azure SWA |
| TXT | `asuid.quixotry.me` | `_32k3o8z4p92ak75p10616fd2mxrrgjo` | Azure domain ownership proof |

**Apex redirect**: `quixotry.me` → Route53 ALIAS → S3 bucket → 301 redirect → `https://www.quixotry.me`. This is necessary because Route53 ALIAS records only support AWS services; the S3 bucket is a redirect-only bucket with no content.

**AWS CLI** (needed for S3/Route53 changes): `pip install awscli`. The `skarumbu` profile (`~/.aws/credentials`) has S3 access but not Route53. Route53 changes must be made via the AWS Console.

## CI/CD

**Static Web App** auto-deploys on push to `main` in `skarumbu/my-website`. The workflow is at `.github/workflows/azure-static-web-apps.yml`. The deployment token is stored as a GitHub Actions secret `AZURE_STATIC_WEB_APPS_API_TOKEN`.

**Digits API** is deployed manually via Kudu zipdeploy (see below). The source files live at `~/digits/`.

## Digits API Deployment

The Digits API uses the Azure Functions v2 Python model (`function_app.py` + `host.json` + `requirements.txt`). Source files are in `~/digits/`.

To redeploy after code changes:
```bash
powershell.exe -Command "Compress-Archive -Force -Path 'C:\Users\Sriram\digits\function_app.py','C:\Users\Sriram\digits\host.json','C:\Users\Sriram\digits\requirements.txt','C:\Users\Sriram\digits\digits_creator.py','C:\Users\Sriram\digits\digits_solver.py','C:\Users\Sriram\digits\nodes.py' -DestinationPath 'C:\Users\Sriram\digits-deploy.zip'"

curl -X POST \
  -u '$digits-api-prod-hwbxtkz6lsfoq:<publishing-password>' \
  --data-binary @/c/Users/Sriram/digits-deploy.zip \
  -H "Content-Type: application/zip" \
  "https://digits-api-prod-hwbxtkz6lsfoq.scm.azurewebsites.net/api/zipdeploy"
```
Get the publishing password via: `az webapp deployment list-publishing-credentials --name digits-api-prod-hwbxtkz6lsfoq --resource-group my-website-prod-rg --query publishingPassword -o tsv`

**Note**: `solve_digits()` mutates the matrix in-place (replaces ints with `Node` objects). When reading matrix values back, use `node.value`.

## Container App (Momentum Finder)

The Uvicorn server runs on **port 80** (not 8000). The Bicep template was corrected (`modules/momentumfinder.bicep` `targetPort: 80`). With `minReplicas: 0`, the app scales to zero when idle — expect cold starts.

## Known Issues

- **Syntax error** in `build-and-deploy-apis.sh` line ~67: `cd ..momentum-finder:latest"` — should be `cd ..`
- CORS on Digits API is currently `*` (all origins)

## Key Parameters (`main.bicep`)

| Parameter | Default | Description |
|-----------|---------|-------------|
| `location` | `eastus` | Primary Azure region |
| `environment` | `prod` | Environment name (used in resource group name) |
| `customDomain` | `https://www.quixotry.me/` | Custom domain for Static Web App |

Note: `deploy.sh` overrides `location` to `centralus` by default.
