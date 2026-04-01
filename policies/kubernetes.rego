package main

deny[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  not container_runs_as_non_root(container)
  msg := sprintf(
    "[DENY][runAsNonRoot] Le conteneur '%v' doit définir securityContext.runAsNonRoot: true",
    [container.name]
  )
}

container_runs_as_non_root(container) {
  container.securityContext.runAsNonRoot == true
}

deny[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  not container.resources.limits
  msg := sprintf(
    "[DENY][resources] Le conteneur '%v' doit définir resources.limits (cpu et memory)",
    [container.name]
  )
}

deny[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  container.securityContext.privileged == true
  msg := sprintf(
    "[DENY][privileged] Le conteneur '%v' ne doit pas s'exécuter en mode privilégié",
    [container.name]
  )
}

deny[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  container.securityContext.allowPrivilegeEscalation == true
  msg := sprintf(
    "[DENY][privesc] Le conteneur '%v' doit définir allowPrivilegeEscalation: false",
    [container.name]
  )
}

warn[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  endswith(container.image, ":latest")
  msg := sprintf(
    "[WARN][tag-latest] Le conteneur '%v' utilise le tag ':latest' — préférer un tag immuable",
    [container.name]
  )
}

warn[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  not contains(container.image, ":")
  msg := sprintf(
    "[WARN][tag-latest] Le conteneur '%v' n'a pas de tag explicite — préférer un tag immuable",
    [container.name]
  )
}

warn[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  not container.securityContext.readOnlyRootFilesystem
  msg := sprintf(
    "[WARN][readOnlyFS] Le conteneur '%v' devrait définir readOnlyRootFilesystem: true",
    [container.name]
  )
}
