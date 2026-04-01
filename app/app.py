from flask import Flask, jsonify, request
import os

app = Flask(__name__)

tasks = [
    {"id": 1, "title": "Apprendre DevSecOps", "done": False},
    {"id": 2, "title": "Configurer GitHub Actions", "done": False},
]


@app.route("/health", methods=["GET"])
def health():
    return jsonify({"status": "ok", "version": "1.0.0"})


@app.route("/tasks", methods=["GET"])
def get_tasks():
    return jsonify(tasks)


@app.route("/tasks/<int:task_id>", methods=["GET"])
def get_task(task_id):
    task = next((t for t in tasks if t["id"] == task_id), None)
    if task is None:
        return jsonify({"error": "Tâche introuvable"}), 404
    return jsonify(task)


@app.route("/tasks", methods=["POST"])
def create_task():
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
    global tasks
    task = next((t for t in tasks if t["id"] == task_id), None)
    if task is None:
        return jsonify({"error": "Tâche introuvable"}), 404
    tasks = [t for t in tasks if t["id"] != task_id]
    return jsonify({"message": "Tâche supprimée"}), 200


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5000))
    app.run(host="0.0.0.0", port=port, debug=False)
