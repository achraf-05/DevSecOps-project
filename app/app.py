"""
DevSecOps TP - API Flask simple (Task Manager)
Réalisé par : Achraf CHERGUI
"""

from flask import Flask, jsonify, request
import os

app = Flask(__name__)

# Base de données en mémoire (simplifiée)
tasks = [
    {"id": 1, "title": "Apprendre DevSecOps", "done": False},
    {"id": 2, "title": "Configurer GitHub Actions", "done": False},
]


@app.route("/health", methods=["GET"])
def health():
    """Endpoint de santé pour les probes Kubernetes."""
    return jsonify({"status": "ok", "version": "1.0.0"})


@app.route("/tasks", methods=["GET"])
def get_tasks():
    """Retourne la liste de toutes les tâches."""
    return jsonify(tasks)


@app.route("/tasks/<int:task_id>", methods=["GET"])
def get_task(task_id):
    """Retourne une tâche par son identifiant."""
    task = next((t for t in tasks if t["id"] == task_id), None)
    if task is None:
        return jsonify({"error": "Tâche introuvable"}), 404
    return jsonify(task)


@app.route("/tasks", methods=["POST"])
def create_task():
    """Crée une nouvelle tâche."""
    data = request.get_json()
    if not data or "title" not in data:
        return jsonify({"error": "Le champ 'title' est requis"}), 400
    task = {
        "id": len(tasks) + 1,
        "title": data["title"],
        "done": False,
    }
    tasks.append(task)
    return jsonify(task), 201


@app.route("/tasks/<int:task_id>", methods=["PUT"])
def update_task(task_id):
    """Met à jour le statut d'une tâche."""
    task = next((t for t in tasks if t["id"] == task_id), None)
    if task is None:
        return jsonify({"error": "Tâche introuvable"}), 404
    data = request.get_json()
    if "done" in data:
        task["done"] = bool(data["done"])
    if "title" in data:
        task["title"] = data["title"]
    return jsonify(task)


@app.route("/tasks/<int:task_id>", methods=["DELETE"])
def delete_task(task_id):
    """Supprime une tâche."""
    global tasks
    task = next((t for t in tasks if t["id"] == task_id), None)
    if task is None:
        return jsonify({"error": "Tâche introuvable"}), 404
    tasks = [t for t in tasks if t["id"] != task_id]
    return jsonify({"message": "Tâche supprimée"}), 200


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5000))
    # NOTE : debug=True ne doit PAS être utilisé en production
    app.run(host="0.0.0.0", port=port, debug=False)
