# Prereqs
- Deploy ML Platform
- Environment variables
```
PROJECT_NUMBER=348087736605
PROJECT_ID=gkebatchexpce3c8dcb
BUCKET=kh-test-data
NAMESPACE=ml-team
KSA=ray-worker
```

# Image Build
```
gcloud builds submit . --tag us-docker.pkg.dev/${PROJECT_ID}/llm/finetune:v1.0.1 --async
```

# Configure GCS
- Model weights and path
    - Gemma 1.1 7b-it - `gs://kh-test-data/hyperparam/model-job-1`
    - Gemma 2 9b-it - `gs://kh-test-data/hyperparam-gemma2/model-job-1`

- Setup Workload Identity Federation to access bucket with model weights
```
gcloud storage buckets add-iam-policy-binding gs://${BUCKET} \
    --member "principal://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${PROJECT_ID}.svc.id.goog/subject/ns/${NAMESPACE}/sa/${KSA}" \
    --role "roles/storage.objectUser"
```

# Deploy the Job

- Modify the `image`, `nodeSelector`, `tolerations` accordingly.

- L4 - On Demand
```
kubectl apply -f yaml/kh-fine-tune-l4.yaml -n ml-team
```

- A100 - DWS
```
kubectl apply -f yaml/kh-provisioningrequest-a2.yaml -n ml-team
kubectl apply -f yaml/kh-fine-tune-a2.yaml -n ml-team
```

- H100 - DWS (MLP example)
```
kubectl apply -f yaml/kh-provisioningrequest-a3.yaml -n ml-team
kubectl apply -f yaml/kh-fine-tune-a3.yaml -n ml-team
```
