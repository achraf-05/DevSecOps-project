# Rapport – TP DevSecOps : Pipeline CI/CD Sécurisé avec GitHub Actions

**Réalisé par : Achraf CHERGUI**
**Date : Avril 2026**

---

## 1. Introduction

Ce travail pratique a pour objectif de mettre en place un pipeline CI/CD intégrant des outils de sécurité
open-source afin d'automatiser la détection de vulnérabilités dans le code, les dépendances, les images
Docker et les configurations Kubernetes. L'ensemble du pipeline est orchestré via GitHub Actions.

Le projet repose sur une petite API REST développée en Flask (Python), conteneurisée avec Docker et
destinée à être déployée sur un cluster Kubernetes.

---

## 2. Description de la démarche

### 2.1 Structure du projet

Le dépôt est organisé comme suit :

```
├── .github/workflows/ci.yml   ← Pipeline GitHub Actions (6 jobs)
├── app/                       ← Code source Flask + requirements.txt
├── k8s/                       ← Manifestes Kubernetes (Deployment, Service)
├── policies/                  ← Règles de sécurité Rego (Conftest)
├── Dockerfile
├── .yamllint.yml
└── .hadolint.yaml
```

### 2.2 Pipeline CI/CD

Le fichier `.github/workflows/ci.yml` définit **6 jobs** déclenchés à chaque `push` sur `main` :

| # | Job | Outil | Rôle |
|---|-----|-------|------|
| 1 | Build | Docker Buildx | Construction et mise en cache de l'image Docker |
| 2 | Lint Dockerfile | Hadolint | Détection des mauvaises pratiques Dockerfile |
| 3 | Lint YAML | yamllint | Validation de la syntaxe des manifestes Kubernetes |
| 4 | Trivy FS | Trivy | Scan des dépendances Python (requirements.txt) |
| 5 | Trivy Image | Trivy | Scan des CVE dans l'image Docker complète |
| 6 | Conftest | OPA / Rego | Vérification des politiques de sécurité Kubernetes |

---

## 3. Vulnérabilités identifiées

### 3.1 Scan des dépendances – Trivy FS

Le scan du fichier `requirements.txt` a révélé plusieurs vulnérabilités sur les dépendances Python :

| Package | Version | CVE | Sévérité | Description |
|---------|---------|-----|----------|-------------|
| Pillow | 9.1.0 | CVE-2022-22817 | **CRITICAL** | Exécution d'expression arbitraire via `PIL.ImageMath.eval()` |
| PyYAML | 5.4.1 | CVE-2020-14343 | **CRITICAL** | Exécution de code arbitraire via `yaml.full_load()` |
| cryptography | 36.0.2 | CVE-2023-49083 | **HIGH** | NULL pointer dereference via parsing PKCS12 malformé |
| Werkzeug | 2.0.1 | CVE-2023-25577 | **HIGH** | Déni de service via parsing multipart/form-data |
| requests | 2.25.1 | CVE-2023-32681 | **MEDIUM** | Fuite du header `Proxy-Authorization` lors d'une redirection |

> **Capture d'écran 1** : Résultats du job `[4/6] Trivy – Scan Dépendances` dans GitHub Actions
> *(insérer capture du log Trivy FS ici)*

### 3.2 Scan de l'image Docker – Trivy Image

En plus des vulnérabilités applicatives, le scan de l'image `python:3.9` (image de base non-slim)
a mis en évidence des CVE supplémentaires au niveau de l'OS et des bibliothèques système embarquées.

> **Capture d'écran 2** : Résultats du job `[5/6] Trivy – Scan Image Docker` dans GitHub Actions
> *(insérer capture du log Trivy image ici)*

---

## 4. Politique de sécurité Kubernetes – Conftest / Rego

### 4.1 Règles définies

Le fichier `policies/kubernetes.rego` contient 4 règles bloquantes (`deny`) et 3 avertissements (`warn`) :

| Règle | Type | Description |
|-------|------|-------------|
| `runAsNonRoot` | DENY | Interdit les pods s'exécutant en root |
| `resources.limits` | DENY | Oblige la définition de limites CPU/mémoire |
| `privileged` | DENY | Interdit le mode conteneur privilégié |
| `allowPrivilegeEscalation` | DENY | Bloque l'escalade de privilèges |
| Tag `:latest` | WARN | Préconise l'utilisation d'un tag immuable |
| `readOnlyRootFilesystem` | WARN | Recommande le FS en lecture seule |

### 4.2 Comportement observé

Dans un premier temps, le manifeste `k8s/deployment.yaml` ne définissait ni `securityContext` ni
`resources.limits`. Le job Conftest a correctement **fait échouer le pipeline** avec les messages :

```
FAIL - k8s/deployment.yaml - [DENY][runAsNonRoot] Le conteneur 'api' doit définir
       securityContext.runAsNonRoot: true
FAIL - k8s/deployment.yaml - [DENY][resources] Le conteneur 'api' doit définir
       resources.limits (cpu et memory)
WARN - k8s/deployment.yaml - [WARN][tag-latest] Le conteneur 'api' utilise le tag ':latest'

2 tests, 0 passed, 0 warnings, 2 failures
```

Après correction du manifeste (ajout du `securityContext` complet et des `resources.limits`),
le job Conftest est passé au vert.

> **Capture d'écran 3** : Job `[6/6] Conftest` en échec (manifeste non conforme)
> *(insérer capture ici)*

> **Capture d'écran 4** : Job `[6/6] Conftest` en succès (manifeste corrigé)
> *(insérer capture ici)*

---

## 5. Analyse de risques et recommandations

### 5.1 Impact potentiel des vulnérabilités majeures

**CVE-2022-22817 – Pillow (CRITICAL)**
L'appel à `PIL.ImageMath.eval()` avec une entrée non filtrée permet à un attaquant d'exécuter
du code Python arbitraire côté serveur. Dans un contexte d'API exposée, cela représente un risque
de compromission totale du conteneur.
→ *Remédiation* : Mettre à jour Pillow vers la version 9.3.0 minimum (`pip install Pillow>=9.3.0`).

**CVE-2020-14343 – PyYAML (CRITICAL)**
La fonction `yaml.full_load()` permet la désérialisation d'objets Python arbitraires. Un attaquant
contrôlant une entrée YAML peut exécuter du code à distance.
→ *Remédiation* : Utiliser `yaml.safe_load()` dans le code et mettre à jour vers PyYAML >= 6.0.

**Pod s'exécutant en root (Conftest)**
Un conteneur sans `runAsNonRoot: true` s'exécute par défaut en UID 0. En cas d'évasion de conteneur
(container escape), l'attaquant obtient des privilèges root sur le nœud Kubernetes.
→ *Remédiation* : Appliquer `runAsNonRoot: true`, `runAsUser: 1000`, `allowPrivilegeEscalation: false`.

**Absence de limites de ressources (Conftest)**
Sans `resources.limits`, un seul pod défaillant peut épuiser le CPU et la mémoire du nœud,
provoquant une indisponibilité en cascade (Denial of Service interne).
→ *Remédiation* : Définir des limites adaptées (`cpu: 250m`, `memory: 256Mi`).

### 5.2 Recommandations générales

**Dépendances Python**
- Mettre à jour toutes les dépendances vers leurs dernières versions stables.
- Activer GitHub Dependabot pour recevoir automatiquement des PR de mise à jour de sécurité.
- Utiliser `pip-audit` en pré-commit pour bloquer l'introduction de nouvelles CVE.

**Durcissement Docker**
- Utiliser une image de base minimale : `python:3.11-slim` réduit significativement la surface d'attaque.
- Ajouter une instruction `USER` dans le Dockerfile pour ne pas exécuter l'application en root.
- Ajouter un `HEALTHCHECK` pour permettre à l'orchestrateur de détecter les pods défaillants.

**Durcissement Kubernetes**
- Appliquer un `SecurityContext` complet sur chaque conteneur (cf. manifeste corrigé).
- Définir des `NetworkPolicy` pour restreindre les communications inter-pods.
- Utiliser des tags d'image immuables (digest SHA256 ou tag sémantique) plutôt que `:latest`.
- Activer l'admission controller `PodSecurityAdmission` avec le profil `restricted`.

---

## 6. Réflexion sur l'intégration de la sécurité dans un pipeline CI/CD

Ce TP illustre concrètement le principe du **Shift Left Security** : en déplaçant les contrôles
de sécurité le plus tôt possible dans le cycle de développement, on réduit à la fois le coût
et l'impact des vulnérabilités découvertes.

Plusieurs enseignements ressortent de cette mise en pratique :

- **L'automatisation est indispensable** : sans pipeline, les scans de dépendances et d'images sont
  souvent omis par manque de temps. GitHub Actions les rend systématiques et non contournables.

- **La sécurité-as-code (Policy as Code)** avec Conftest/Rego permet de codifier des exigences
  de sécurité organisationnelles et de les faire respecter de manière uniforme sur tous les projets,
  sans dépendre de revues manuelles.

- **Les outils open-source comme Trivy** offrent une couverture de vulnérabilités comparable
  aux solutions commerciales, rendant l'approche DevSecOps accessible sans budget spécifique.

- **Les faux positifs et la gestion du bruit** constituent le principal défi opérationnel :
  trop de règles bloquantes sans tri peut décourager les équipes. Il est essentiel de calibrer
  les seuils (CRITICAL bloquant, MEDIUM informatif) pour maintenir l'adhésion des développeurs.

En synthèse, un pipeline DevSecOps bien configuré transforme la sécurité d'une contrainte
perçue comme frein en un filet de sécurité transparent, intégré naturellement dans le flux
de développement.

---

*Réalisé par : Achraf CHERGUI — Avril 2026*
