# ─────────────────────────────────────────────────────────────────────────────
# Politique de sécurité Kubernetes – Conftest / Rego
# Réalisé par : Achraf CHERGUI
#
# Ce fichier définit les règles de sécurité appliquées aux manifestes Kubernetes
# via Conftest. Un `deny` fait échouer le pipeline ; un `warn` est informatif.
#
# Exécution manuelle :
#   conftest test k8s/ --policy policies/
# ─────────────────────────────────────────────────────────────────────────────

package main

# ─── Règle 1 : runAsNonRoot obligatoire ──────────────────────────────────────
# Un pod ne doit pas pouvoir s'exécuter en tant qu'utilisateur root (UID 0).
# Impact : si un attaquant compromet le conteneur, il obtient des droits root
# sur le nœud via une évasion de conteneur.

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

# ─── Règle 2 : Limites de ressources obligatoires ────────────────────────────
# Chaque conteneur doit définir resources.limits (CPU + mémoire).
# Impact : sans limites, un conteneur défaillant peut consommer toutes les
# ressources du nœud (Denial of Service).

deny[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  not container.resources.limits
  msg := sprintf(
    "[DENY][resources] Le conteneur '%v' doit définir resources.limits (cpu et memory)",
    [container.name]
  )
}

# ─── Règle 3 : Interdire le mode privilégié ──────────────────────────────────
# Un conteneur privilégié a accès au nœud hôte avec des droits quasi-root.

deny[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  container.securityContext.privileged == true
  msg := sprintf(
    "[DENY][privileged] Le conteneur '%v' ne doit pas s'exécuter en mode privilégié",
    [container.name]
  )
}

# ─── Règle 4 : allowPrivilegeEscalation doit être false ──────────────────────

deny[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  container.securityContext.allowPrivilegeEscalation == true
  msg := sprintf(
    "[DENY][privesc] Le conteneur '%v' doit définir allowPrivilegeEscalation: false",
    [container.name]
  )
}

# ─── Avertissement 1 : Tag ':latest' déconseillé ─────────────────────────────
# Utiliser ':latest' rend les déploiements non reproductibles.

warn[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  endswith(container.image, ":latest")
  msg := sprintf(
    "[WARN][tag-latest] Le conteneur '%v' utilise le tag ':latest' — préférer un tag immuable (ex: sha256 ou version sémantique)",
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

# ─── Avertissement 2 : readOnlyRootFilesystem recommandé ─────────────────────

warn[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  not container.securityContext.readOnlyRootFilesystem
  msg := sprintf(
    "[WARN][readOnlyFS] Le conteneur '%v' devrait définir readOnlyRootFilesystem: true",
    [container.name]
  )
}
