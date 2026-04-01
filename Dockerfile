# ─────────────────────────────────────────────────────────────────────────────
# Dockerfile – DevSecOps TP
# Réalisé par : Achraf CHERGUI
#
# NOTE PÉDAGOGIQUE :
#   Ce Dockerfile contient des mauvaises pratiques intentionnelles afin de
#   démontrer les alertes générées par Hadolint et Trivy :
#     - Image de base non-slim/alpine (plus de CVE détectées)
#     - Exécution en tant que root (pas d'instruction USER)
#     - Pas de HEALTHCHECK défini
#   Ces points sont à corriger dans un environnement de production.
# ─────────────────────────────────────────────────────────────────────────────

# [HADOLINT DL3006] Utiliser un tag précis plutôt que latest
FROM python:3.9

# Métadonnées
LABEL maintainer="Achraf CHERGUI"
LABEL description="API Flask pour le TP DevSecOps"

# Répertoire de travail
WORKDIR /app

# Copie des dépendances en premier (layer cache)
COPY app/requirements.txt .

# [HADOLINT DL3013] Pas de --no-cache-dir ni de version figée sur pip
RUN pip install --no-cache-dir -r requirements.txt

# Copie du code source
COPY app/ .

# Port exposé
EXPOSE 5000

# [BONNE PRATIQUE MANQUANTE] Aucune instruction USER → s'exécute en root
# Ajouter en production :
#   RUN addgroup --system appgroup && adduser --system --ingroup appgroup appuser
#   USER appuser

# Démarrage de l'application avec Gunicorn
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "app:app"]
