_beacon_existing() {
  kubectl get secret "$2" -n "$1" -o "jsonpath={.data.$3}" 2>/dev/null | base64 -d 2>/dev/null
}

if [ -z "${TF_VAR_dockerhub_token:-}" ]; then
  TF_VAR_dockerhub_token="$(_beacon_existing jenkins dockerhub token)"
  if [ -z "$TF_VAR_dockerhub_token" ]; then
    printf 'Docker Hub access token: '
    stty -echo; read -r TF_VAR_dockerhub_token; stty echo; echo
  fi
  export TF_VAR_dockerhub_token
fi

if [ -z "${TF_VAR_jenkins_admin_password:-}" ]; then
  TF_VAR_jenkins_admin_password="$(_beacon_existing jenkins jenkins-admin jenkins-admin-password)"
  if [ -z "$TF_VAR_jenkins_admin_password" ]; then
    TF_VAR_jenkins_admin_password="$(openssl rand -base64 24)"
    echo "Generated a new Jenkins admin password (read it later from the jenkins-admin Secret)."
  fi
  export TF_VAR_jenkins_admin_password
fi

if [ -z "${TF_VAR_github_token:-}" ]; then
  TF_VAR_github_token="$(_beacon_existing jenkins gitops token)"
  if [ -z "$TF_VAR_github_token" ]; then
    printf 'GitHub fine-grained token (beacon-gitops, Contents read/write): '
    stty -echo; read -r TF_VAR_github_token; stty echo; echo
  fi
  export TF_VAR_github_token
fi

if [ -z "${TF_VAR_grafana_admin_password:-}" ]; then
  TF_VAR_grafana_admin_password="$(_beacon_existing monitoring grafana-admin admin-password)"
  if [ -z "$TF_VAR_grafana_admin_password" ]; then
    TF_VAR_grafana_admin_password="$(openssl rand -base64 24)"
    echo "Generated a new Grafana admin password (read it later from the grafana-admin Secret)."
  fi
  export TF_VAR_grafana_admin_password
fi

unset -f _beacon_existing
[ -n "$TF_VAR_dockerhub_token" ] && [ -n "$TF_VAR_jenkins_admin_password" ] && [ -n "$TF_VAR_github_token" ] && [ -n "$TF_VAR_grafana_admin_password" ] \
  && echo "Secrets loaded: TF_VAR_dockerhub_token, TF_VAR_jenkins_admin_password, TF_VAR_github_token, TF_VAR_grafana_admin_password" \
  || echo "WARNING: a secret is empty; do not run terraform apply"
