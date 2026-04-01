# TP DevSecOps – Pipeline CI/CD Sécurisé avec GitHub Actions

**Réalisé par : Achraf CHERGUI**

---

## Structure du projet

```
.
├── .github/
│   └── workflows/
│       └── ci.yml              ← Pipeline CI/CD GitHub Actions
├── app/
│   ├── app.py                  ← API Flask (Task Manager)
│   └── requirements.txt        ← Dépendances Python
├── k8s/
│   ├── deployment.yaml         ← Manifeste Kubernetes (Deployment)
│   └── service.yaml            ← Manifeste Kubernetes (Service)
├── policies/
│   └── kubernetes.rego         ← Règles de sécurité Conftest/Rego
├── Dockerfile                  ← Image Docker de l'application
├── .dockerignore
├── .yamllint.yml               ← Configuration yamllint
├── .hadolint.yaml              ← Configuration Hadolint
└── README.md
```

---

## Étape 1 – Préparation

### Cloner et initialiser le dépôt

```bash
git clone <votre-repo>
cd devsecops-tp
```

### Exécution locale (optionnel)

```bash
# Avec Python
cd app
pip install -r requirements.txt
python app.py

# Avec Docker
docker build -t devsecops-api:local .
docker run -p 5000:5000 devsecops-api:local
```

Tester l'API :
```bash
curl http://localhost:5000/health
curl http://localhost:5000/tasks
curl -X POST http://localhost:5000/tasks \
  -H "Content-Type: application/json" \
  -d '{"title": "Ma nouvelle tâche"}'
```

---

## Étape 2 – Pipeline CI/CD GitHub Actions

Le fichier `.github/workflows/ci.yml` définit 6 jobs exécutés à chaque `push` sur `main` ou `develop` :

| # | Job | Outil | Description |
|---|-----|-------|-------------|
| 1 | `build` | Docker Buildx | Construction de l'image Docker |
| 2 | `lint-dockerfile` | Hadolint | Analyse statique du Dockerfile |
| 3 | `lint-yaml` | yamllint | Lint des manifestes Kubernetes |
| 4 | `trivy-deps` | Trivy FS | Scan des dépendances Python |
| 5 | `trivy-container` | Trivy image | Scan de l'image Docker |
| 6 | `conftest` | Conftest/Rego | Vérification des politiques K8s |

---

## Étape 3 – Scan de sécurité avec Trivy

### Scan local des dépendances

```bash
trivy fs --severity CRITICAL,HIGH,MEDIUM .
```

### Scan local de l'image Docker

```bash
docker build -t devsecops-api:local .
trivy image --severity CRITICAL,HIGH,MEDIUM devsecops-api:local
```

### Vulnérabilités attendues (exemples)

Les dépendances dans `requirements.txt` sont intentionnellement anciennes pour démontrer les capacités de Trivy :

| Package | Version | CVE | Sévérité | Description |
|---------|---------|-----|----------|-------------|
| Pillow | 9.1.0 | CVE-2022-22817 | CRITICAL | Expression arbitraire via PIL.ImageMath.eval |
| cryptography | 36.0.2 | CVE-2023-49083 | HIGH | NULL pointer dereference via PKCS12 |
| PyYAML | 5.4.1 | CVE-2020-14343 | CRITICAL | Exécution de code arbitraire via full_load |
| requests | 2.25.1 | CVE-2023-32681 | MEDIUM | Fuite de Proxy-Authorization header |
| Werkzeug | 2.0.1 | CVE-2023-25577 | HIGH | DoS via parsing de multipart/form-data |

---

## Étape 4 – Politique de sécurité Conftest/Rego

### Règles définies dans `policies/kubernetes.rego`

| Règle | Type | Description |
|-------|------|-------------|
| `runAsNonRoot` | DENY | Le conteneur doit définir `securityContext.runAsNonRoot: true` |
| `resources.limits` | DENY | CPU et mémoire doivent être limités |
| `privileged` | DENY | Le mode privilégié est interdit |
| `allowPrivilegeEscalation` | DENY | L'escalade de privilèges est interdite |
| Tag `:latest` | WARN | Préférer un tag immuable |
| `readOnlyRootFilesystem` | WARN | Système de fichiers en lecture seule recommandé |

### Tester les politiques localement

```bash
# Installation de Conftest
CONFTEST_VERSION="0.50.0"
wget https://github.com/open-policy-agent/conftest/releases/download/v${CONFTEST_VERSION}/conftest_${CONFTEST_VERSION}_Linux_x86_64.tar.gz
tar xzf conftest_${CONFTEST_VERSION}_Linux_x86_64.tar.gz
sudo mv conftest /usr/local/bin/

# Vérification (doit ECHOUER sur le manifeste non corrigé)
conftest test k8s/deployment.yaml --policy policies/
```

### Sortie attendue (manifeste non corrigé)

```
FAIL - k8s/deployment.yaml - main - [DENY][runAsNonRoot] Le conteneur 'api' doit définir securityContext.runAsNonRoot: true
FAIL - k8s/deployment.yaml - main - [DENY][resources] Le conteneur 'api' doit définir resources.limits (cpu et memory)
WARN - k8s/deployment.yaml - main - [WARN][tag-latest] Le conteneur 'api' utilise le tag ':latest'
WARN - k8s/deployment.yaml - main - [WARN][readOnlyFS] Le conteneur 'api' devrait définir readOnlyRootFilesystem: true

2 tests, 0 passed, 0 warnings, 2 failures, 0 exceptions
```

### Corriger le manifeste

Dans `k8s/deployment.yaml`, décommenter le bloc `# CORRECTION` pour rendre le pod conforme.

---

## Étape 5 – Activer GitHub Dependabot

Créer le fichier `.github/dependabot.yml` :

```yaml
version: 2
updates:
  - package-ecosystem: pip
    directory: "/app"
    schedule:
      interval: weekly
    open-pull-requests-limit: 5
```

---

## Recommandations de remédiation

### Dépendances Python
- Mettre à jour toutes les dépendances vers leurs dernières versions stables
- Utiliser `pip-audit` ou Dependabot pour une surveillance continue
- Fixer les versions exactes dans `requirements.txt`

### Dockerfile
- Utiliser une image de base minimale : `python:3.11-slim` ou `python:3.11-alpine`
- Ajouter une instruction `USER` pour ne pas s'exécuter en root :
  ```dockerfile
  RUN addgroup --system appgroup && adduser --system --ingroup appgroup appuser
  USER appuser
  ```
- Ajouter un `HEALTHCHECK` :
  ```dockerfile
  HEALTHCHECK --interval=30s --timeout=5s CMD curl -f http://localhost:5000/health || exit 1
  ```

### Kubernetes
- Définir `securityContext.runAsNonRoot: true` et `runAsUser: 1000`
- Définir `allowPrivilegeEscalation: false`
- Définir `readOnlyRootFilesystem: true`
- Toujours spécifier `resources.limits` et `resources.requests`
- Utiliser des tags d'image immuables (digest SHA256)
- Activer les Network Policies pour limiter le trafic inter-pods

---

## Outils utilisés

| Outil | Rôle | Documentation |
|-------|------|---------------|
| GitHub Actions | Orchestration CI/CD | https://docs.github.com/actions |
| Trivy | Scan vulnérabilités (deps + image) | https://aquasecurity.github.io/trivy |
| Hadolint | Lint Dockerfile | https://github.com/hadolint/hadolint |
| yamllint | Lint YAML | https://yamllint.readthedocs.io |
| Conftest | Politique de sécurité (Rego) | https://www.conftest.dev |
| OPA/Rego | Langage de politique | https://www.openpolicyagent.org |
