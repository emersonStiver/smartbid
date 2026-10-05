# Deploy targets, read by the cicd-pipeline stack: /<project>/cicd/<env>/{account-id,deploy-role-arn}
resource "aws_ssm_parameter" "deploy_account_id" {
  #checkov:skip=CKV2_AWS_34:Account IDs are not secrets
  for_each = var.deploy_targets
  name     = "/${var.project}/cicd/${each.key}/account-id"
  type     = "String"
  value    = each.value.account_id
}

resource "aws_ssm_parameter" "deploy_role_arn" {
  #checkov:skip=CKV2_AWS_34:Role ARNs are not secrets
  for_each = var.deploy_targets
  name     = "/${var.project}/cicd/${each.key}/deploy-role-arn"
  type     = "String"
  value    = local.deploy_role_arns[each.key]
}
