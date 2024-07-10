# Create build triggers finetune
```
gcloud builds triggers create github \
    --name=build-finetune-test \
    --region=us-central1 \
    --repository="projects/gkebatchexpce3c8dcb/locations/us-central1/connections/cloudml-ops/repositories/cloud-mlops-fine-tuning" \
    --branch-pattern="^main$" \
    --build-config="finetune-gemma/cloudbuild.yaml" \
    --included-files="finetune-gemma/fine_tune.py,finetune-gemma/requirements.txt" \
    --substitutions='_VERSION=$SHORT_SHA'
```

gcloud pubsub topics create gcr --project=gkebatchexpce3c8dcb
gcloud pubsub subscriptions create ar-sub --topic=gcr --project=gkebatchexpce3c8dcb

# deploy-gke-ss
# kubernetes engine admin
# log writer
# roles/gkehub.gatewayEditor
# roles/gkehub.viewer

# pubsub trigger
```
gcloud builds triggers create pubsub \
    --name=trigger-deploy-finetune-job \
    --region=us-central1 \
    --topic=projects/gkebatchexpce3c8dcb/topics/gcr \
    --build-config=finetune-gemma/cloudbuild-deploy.yaml \
    --repository="projects/gkebatchexpce3c8dcb/locations/us-central1/connections/cloudml-ops/repositories/cloud-mlops-fine-tuning" \
    --branch="main" \
    --substitutions='_IMAGE_TAG=$(body.message.data.tag)','_ACTION=$(body.message.data.action)','_IMAGE_VERSION=${_IMAGE_TAG##*:}','_ACCELERATOR=a100','_CLUSTER_NAME=mlp-kenthua' \
    --subscription-filter='_IMAGE_TAG.matches("(us-docker.pkg.dev/gkebatchexpce3c8dcb/llm/finetune)(?::.+)?") && _ACTION.matches("INSERT")' \
    --service-account="projects/gkebatchexpce3c8dcb/serviceAccounts/deploy-gke-sa@gkebatchexpce3c8dcb.iam.gserviceaccount.com"
```