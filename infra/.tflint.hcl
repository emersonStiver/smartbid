# TFLint config: catches errors terraform validate misses
# (invalid instance types, deprecated syntax, unused variables, naming).
# Install plugins once with: tflint --init

config {
  call_module_type = "local" # also lint the local modules each layer calls
}

plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

plugin "aws" {
  enabled = true
  version = "0.49.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}
