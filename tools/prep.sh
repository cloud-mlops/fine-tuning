gcloud storage buckets add-iam-policy-binding gs://kh-ml-data \
    --member "principal://iam.googleapis.com/projects/348087736605/locations/global/workloadIdentityPools/gkebatchexpce3c8dcb.svc.id.goog/subject/ns/ml-tools/sa/mlflow" \
    --role "roles/storage.objectUser"

kubectl apply -f ns.yaml
kubectl apply -f sa.yaml -n ml-tools
kubectl apply -f mlflow.yaml -n ml-tools