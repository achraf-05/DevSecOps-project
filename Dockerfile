FROM python:3.9

LABEL maintainer="Achraf CHERGUI"
LABEL description="API Flask – DevSecOps TP"

WORKDIR /app

COPY app/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app/ .

EXPOSE 5000

CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "app:app"]
