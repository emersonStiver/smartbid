# shared/cicd-pipeline — CodePipeline V2: Source -> Validate -> IntegrationTest -> Package -> DeployDev
#                         (-> ApproveProd -> DeployProd when enable_prod_stages = true)
# Requires: cicd-foundation, cicd-builds and environments/dev/services applied; connection AVAILABLE.

data "terraform_remote_state" "foundation" {
  backend = "s3"
  config = {
    bucket = "emer-tfstate-${var.environment}-${var.account_id}"
    key    = "cicd-foundation/terraform.tfstate"
    region = "us-east-1"
  }
}

data "terraform_remote_state" "builds" {
  backend = "s3"
  config = {
    bucket = "emer-tfstate-${var.environment}-${var.account_id}"
    key    = "cicd-builds/terraform.tfstate"
    region = "us-east-1"
  }
}

# Written by cicd-foundation: /<project>/cicd/<env>/deploy-role-arn
data "aws_ssm_parameter" "deploy_role_arn" {
  for_each = var.deploy_environments
  name     = "/${var.project}/cicd/${each.key}/deploy-role-arn"
}

locals {
  f        = data.terraform_remote_state.foundation.outputs
  projects = data.terraform_remote_state.builds.outputs.project_names

  # Every CodeBuild action gets the commit being built (also the image tag)
  commit_env = jsonencode([{ name = "COMMIT_ID", value = "#{SourceVariables.CommitId}", type = "PLAINTEXT" }])

  prod_enabled = var.enable_prod_stages && contains(keys(var.deploy_environments), "prod")
}

resource "aws_codepipeline" "this" {
  name           = "${var.project}-pipeline"
  pipeline_type  = "V2"
  execution_mode = "QUEUED"
  role_arn       = local.f.codepipeline_role_arn

  artifact_store {
    type     = "S3"
    location = local.f.artifacts_bucket_name
    encryption_key {
      type = "KMS"
      id   = local.f.artifacts_kms_key_arn
    }
  }

  # Start only on pushes to main that touch the service, buildspecs or integration tests
  trigger {
    provider_type = "CodeStarSourceConnection"
    git_configuration {
      source_action_name = "Source"
      push {
        branches {
          includes = [var.main_branch]
        }
        file_paths {
          includes = var.trigger_file_paths
        }
      }
    }
  }

  stage {
    name = "Source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      namespace        = "SourceVariables"
      output_artifacts = ["SourceOutput"]
      configuration = {
        ConnectionArn        = local.f.connection_arn
        FullRepositoryId     = var.github_repository
        BranchName           = var.main_branch
        OutputArtifactFormat = "CODE_ZIP"
      }
    }
  }

  stage {
    name = "Validate"
    action {
      name            = "BuildTest"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      version         = "1"
      run_order       = 1
      input_artifacts = ["SourceOutput"]
      configuration = {
        ProjectName          = local.projects.build_test
        EnvironmentVariables = local.commit_env
      }
    }
    action {
      name            = "SecurityScan"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      version         = "1"
      run_order       = 1 # same run_order = runs in parallel with BuildTest
      input_artifacts = ["SourceOutput"]
      configuration = {
        ProjectName          = local.projects.security_scan
        EnvironmentVariables = local.commit_env
      }
    }
  }

  stage {
    name = "IntegrationTest"
    action {
      name            = "IntegrationTest"
      category        = "Test"
      owner           = "AWS"
      provider        = "CodeBuild"
      version         = "1"
      input_artifacts = ["SourceOutput"]
      configuration = {
        ProjectName          = local.projects.integration_test
        EnvironmentVariables = local.commit_env
      }
    }
  }

  stage {
    name = "Package"
    action {
      name             = "PackagePublish"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      namespace        = "PackageVariables" # exports IMAGE_TAG and IMAGE_URI
      input_artifacts  = ["SourceOutput"]
      output_artifacts = ["ImageDefinitions"]
      configuration = {
        ProjectName          = local.projects.package_publish
        EnvironmentVariables = local.commit_env
      }
    }
  }

  stage {
    name = "DeployDev"
    action {
      name            = "DeployDev"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ECS"
      version         = "1"
      input_artifacts = ["ImageDefinitions"]
      role_arn        = data.aws_ssm_parameter.deploy_role_arn["dev"].insecure_value # cross-account
      region          = local.f.region
      configuration = {
        ClusterName       = var.deploy_environments["dev"].cluster_name
        ServiceName       = var.deploy_environments["dev"].service_name
        FileName          = "imagedefinitions.json"
        DeploymentTimeout = "15"
      }
    }
  }

  dynamic "stage" {
    for_each = local.prod_enabled ? [1] : []
    content {
      name = "ApproveProd"
      action {
        name     = "ApproveProd"
        category = "Approval"
        owner    = "AWS"
        provider = "Manual"
        version  = "1"
        configuration = {
          CustomData = "Deploy image #{PackageVariables.IMAGE_TAG} to prod?"
        }
      }
    }
  }

  dynamic "stage" {
    for_each = local.prod_enabled ? [1] : []
    content {
      name = "DeployProd"
      action {
        name            = "DeployProd"
        category        = "Deploy"
        owner           = "AWS"
        provider        = "ECS"
        version         = "1"
        input_artifacts = ["ImageDefinitions"]
        role_arn        = data.aws_ssm_parameter.deploy_role_arn["prod"].insecure_value
        region          = local.f.region
        configuration = {
          ClusterName       = var.deploy_environments["prod"].cluster_name
          ServiceName       = var.deploy_environments["prod"].service_name
          FileName          = "imagedefinitions.json"
          DeploymentTimeout = "15"
        }
      }
    }
  }
}