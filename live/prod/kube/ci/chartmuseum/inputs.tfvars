release_spec = {
  enabled        = true
  release_name   = "chartmuseum"
  release_values = "values.yaml"

  chart_repo    = "incubator"
  chart_name    = "chartmuseum"
  chart_version = "0.3.1"

  domain_name = "charts.swarm.pw"
}

basic_auth_secret = {
  file = "secrets/chartrepo.htpasswd"
}

post_hook = {
  command = "sleep 10"
}