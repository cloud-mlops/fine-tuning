```
export PROJECT_ID=gkebatchexpce3c8dcb

gcloud projects add-iam-policy-binding projects/${PROJECT_ID} \
    --role=roles/aiplatform.user \
    --member=principal://iam.googleapis.com/projects/348087736605/locations/global/workloadIdentityPools/${PROJECT_ID}.svc.id.goog/subject/ns/ml-team/sa/ray-worker \
    --condition=None
```