# cicd-foundation

This stack owns the `myapp-github` CodeConnections connection that lets AWS read the GitHub repo.

## Important: the connection is created in `PENDING` status

Terraform cannot finish the GitHub authorization. After the first `apply`:

1. AWS Console → Developer Tools → Settings → Connections → select the connection → **Update pending connection**.
2. Install the **AWS Connector for GitHub** app on the GitHub organization.
3. Under *Repository access*, choose **Only select repositories** and pick this repo.
4. The status changes to `AVAILABLE`. CodeBuild and CodePipeline can now use the connection ARN.

## Inputs

## Outputs

## Usage
