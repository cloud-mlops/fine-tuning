# Prereqs
- Deploy ML Platform
- Environment variables
```
export PROJECT_NUMBER=348087736605
export PROJECT_ID=gkebatchexpce3c8dcb
export BUCKET=kh-test-data
export NAMESPACE=ml-team
export KSA=ray-worker
export HF_TOKEN=<your token>
```

- Create secret for HF in your namespace
```
kubectl create secret generic hf-secret \
  --from-literal=hf_api_token=${HF_TOKEN} \
  --dry-run=client -o yaml | kubectl apply -n ml-team -f -
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

- L4 - DWS
```
kubectl apply -f yaml/provisioning-request-l4.yaml -n ml-team
kubectl apply -f yaml/fine-tune-l4.yaml -n ml-team
```

- A100 - DWS
```
kubectl apply -f yaml/provisioning-request-a2.yaml -n ml-team
kubectl apply -f yaml/fine-tune-a2.yaml -n ml-team
```

- H100 - DWS
```
kubectl apply -f yaml/provisioning-request-a3.yaml -n ml-team
kubectl apply -f yaml/fine-tune-a3.yaml -n ml-team
```
