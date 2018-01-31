release_spec = {
  enabled        = false
  release_name   = "wordpress-app"
  release_values = "values.yaml"

  chart_repo    = "stable"
  chart_name    = "wordpress"
  chart_version = "0.7.10"

  domain_name = "wp.swarm.pw"
}
