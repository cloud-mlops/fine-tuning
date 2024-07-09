mlflow is deployed to track fine-tuning experiments

# Prereqs
- GCS

# Details
The default backend store is specified to be in `/mlruns/mlruns.db`
GCS bucket is mounted in the `/mlruns` path.
A sqlite backend is configured to store the experiments by mlflow.

# Install
```
kubectl apply -f ns.yaml
kubectl apply -f sa.yaml -n ml-tools
kubectl apply -f mlflow-sql.yaml
```

# Other dependencies
- The mlflow image would need to be built to support:
    - Prometheus export are primarily for the platform, requires this python library `prometheus_flask_exporter`
    - Postgres is supported, but requires the library `psycopg2-binary`
