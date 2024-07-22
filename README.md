# Cloud Build Trigger Setup for fine-tuning e2e

As part of the many steps in order to perform the fine-tuning of a model, below are
example triggers to help automate the process from data preparation to validation.

- Triggers to build the respective image for each step in the process
- Triggers for respective image pushes and bucket additions
    - Data Prep Job - artifact registry trigger on new image
    - Fine-tuning Job - artifact registry trigger on new image
    - Data Prep Job - data trigger on new preprocessed data (not yet implemented)
    - Fine-tuning Job - data trigger on new prompt generated data set
    - Model evaluation Job - data trigger on new fine-tuned model
    - Fine-tuning Hyperparameter - code trigger based on updated `params.env` to launch N jobs

# Prereq
```
export PROJECT_ID=gkebatchexpce3c8dcb
export REGION=us-central1
export SERVICE_ACCOUNT_NAME=deploy-gke-sa
```
# Create the repository connection to GitHub
- To do this in the [UI](https://cloud.google.com/build/docs/automating-builds/github/connect-repo-github?generation=2nd-gen#connecting_a_github_host)

- To do this in the [CLI](https://cloud.google.com/build/docs/automating-builds/github/connect-repo-github?generation=2nd-gen#gcloud)

- Set repository environment variables
```
# the repository values will differ depending on your setup
export REPOSITORY_CONNECTION_NAME=cloudml-ops
export REPOSITORY=cloud-mlops-fine-tuning
```

# Create Cloud Build triggers to build docker images
## For dataprep
```
gcloud builds triggers create github \
    --name=build-dataprep-image \
    --region=${REGION} \
    --repository="projects/${PROJECT_ID}/locations/${REGION}/connections/${REPOSITORY_CONNECTION_NAME}/repositories/${REPOSITORY}" \
    --branch-pattern="^main$" \
    --build-config="dataprep/cloudbuild.yaml" \
    --included-files="dataprep/dataprep.py,dataprep/requirements.txt" \
    --substitutions='_VERSION=$SHORT_SHA'
```

## For finetune
```
gcloud builds triggers create github \
    --name=build-finetune-image \
    --region=${REGION} \
    --repository="projects/${PROJECT_ID}/locations/${REGION}/connections/${REPOSITORY_CONNECTION_NAME}/repositories/${REPOSITORY}" \
    --branch-pattern="^main$" \
    --build-config="finetune-gemma/cloudbuild.yaml" \
    --included-files="finetune-gemma/fine_tune.py,finetune-gemma/requirements.txt" \
    --substitutions='_VERSION=$SHORT_SHA'
```

## For model-eval
```
gcloud builds triggers create github \
    --name=build-model-eval-image \
    --region=${REGION} \
    --repository="projects/${PROJECT_ID}/locations/${REGION}/connections/${REPOSITORY_CONNECTION_NAME}/repositories/${REPOSITORY}" \
    --branch-pattern="^main$" \
    --build-config="model-eval/cloudbuild.yaml" \
    --included-files="model-eval/validate_fine_tuned_model.py,model-eval/requirements.txt" \
    --substitutions='_VERSION=$SHORT_SHA'
```

# Cloud Build Pub/Sub Artifact Registry Trigger to provision resources in cluster
- Create the topic for Artifact Registry to trigger on image addition
```
gcloud pubsub topics create gcr --project=${PROJECT_ID}
#gcloud pubsub subscriptions create ar-sub --topic=gcr --project=${PROJECT_ID}
```

- Create Service Account to be used for the pub/sub trigger
```
gcloud iam service-accounts create ${SERVICE_ACCOUNT_NAME} \
  --description="GKE SA for Cloud Build"
```

- Assign valid roles
```
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member=serviceAccount:${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com \
    --role=roles/gkehub.gatewayEditor \
    --condition=None

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member=serviceAccount:${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com \
    --role=roles/gkehub.viewer \
    --condition=None

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member=serviceAccount:${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com \
    --role=roles/logging.logWriter \
    --condition=None

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member=serviceAccount:${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com \
    --role=roles/storage.objectUser \
    --condition=None
```

## Deploy dataprep
```
gcloud builds triggers create pubsub \
    --name=trigger-deploy-dataprep-job \
    --region=${REGION} \
    --topic=projects/${PROJECT_ID}/topics/gcr \
    --build-config=dataprep/cloudbuild-deploy.yaml \
    --repository="projects/${PROJECT_ID}/locations/${REGION}/connections/${REPOSITORY_CONNECTION_NAME}/repositories/${REPOSITORY}" \
    --branch="main" \
    --substitutions='_IMAGE_TAG=$(body.message.data.tag)','_ACTION=$(body.message.data.action)','_IMAGE_VERSION=${_IMAGE_TAG##*:}','_CLUSTER_NAME=mlp-kenthua','_BUCKET=kh-finetune-ds','_DATASET_INPUT_PATH=flipkart_preprocessed_dataset','_DATASET_INPUT_FILE=flipkart.csv','_PROMPT_MODEL_ID=gemini-1.5-flash-001','_VERTEX_REGION=us-central1' \
    --subscription-filter='_IMAGE_TAG.matches("(us-docker.pkg.dev/gkebatchexpce3c8dcb/llm/dataprep)(?::.+)?") && _ACTION.matches("INSERT")' \
    --service-account="projects/${PROJECT_ID}/serviceAccounts/${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
```

## Deploy finetune
```
gcloud builds triggers create pubsub \
    --name=trigger-deploy-finetune-job \
    --region=${REGION} \
    --topic=projects/${PROJECT_ID}/topics/gcr \
    --build-config=finetune-gemma/cloudbuild-deploy.yaml \
    --repository="projects/${PROJECT_ID}/locations/${REGION}/connections/${REPOSITORY_CONNECTION_NAME}/repositories/${REPOSITORY}" \
    --branch="main" \
    --substitutions='_IMAGE_TAG=$(body.message.data.tag)','_ACTION=$(body.message.data.action)','_IMAGE_VERSION=${_IMAGE_TAG##*:}','_ACCELERATOR=a100','_CLUSTER_NAME=mlp-kenthua','_TRAINING_DATASET_PATH=/new-format/dataset-it/training','_MODEL_BUCKET=kr-finetune' \
    --subscription-filter='_IMAGE_TAG.matches("(us-docker.pkg.dev/gkebatchexpce3c8dcb/llm/finetune)(?::.+)?") && _ACTION.matches("INSERT")' \
    --service-account="projects/${PROJECT_ID}/serviceAccounts/${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
```

# Cloud Build Pub/Sub GCS Trigger To Provision Resources in Cluster
- Allow GCS bucket to publish
```
SERVICE_ACCOUNT="$(gsutil kms serviceaccount -p ${PROJECT_ID})"
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member="serviceAccount:${SERVICE_ACCOUNT}" \
    --role='roles/pubsub.publisher' \
    --condition=None
```

## Create the trigger for new training dataset in GCS
- Create the GCS Pub/Sub topic to trigger fine tuning
```
BUCKET=kh-finetune-ds
TOPIC=${BUCKET}-topic
gcloud storage buckets notifications create gs://${BUCKET} --topic=${TOPIC}
```

- Create the trigger
```
gcloud builds triggers create pubsub \
    --name=trigger-deploy-finetune-job-new-data \
    --region=${REGION} \
    --topic=projects/${PROJECT_ID}/topics/${TOPIC} \
    --build-config=finetune-gemma/cloudbuild-gcs-deploy.yaml \
    --repository="projects/${PROJECT_ID}/locations/${REGION}/connections/${REPOSITORY_CONNECTION_NAME}/repositories/${REPOSITORY}" \
    --branch="main" \
    --substitutions='_EVENT_TYPE=$(body.message.attributes.eventType)','_BUCKET_ID=$(body.message.attributes.bucketId)','_OBJECT_ID=$(body.message.attributes.objectId)','_IMAGE_TAG=us-docker.pkg.dev/gkebatchexpce3c8dcb/llm/finetune:18c085a','_IMAGE_VERSION=${_IMAGE_TAG##*:}','_ACCELERATOR=a100','_CLUSTER_NAME=mlp-kenthua','_TRAINING_DATASET_PATH=${_OBJECT_ID/\/state.json/}','_DATA_COMMIT=${_TRAINING_DATASET_PATH##*-}' \
    --subscription-filter='_EVENT_TYPE.matches("OBJECT_FINALIZE") && _OBJECT_ID.matches("^(.*)training/state.json$") && _BUCKET_ID.matches("^kh-finetune-ds$")'
```

## Create the trigger for fine-tuned model evaluation
- Create the GCS Pub/Sub topic to trigger model eval
```
BUCKET=kr-finetune
TOPIC=${BUCKET}-topic
gcloud storage buckets notifications create gs://${BUCKET} --topic=${TOPIC}
```

- Create the trigger
```
gcloud builds triggers create pubsub \
    --name=trigger-deploy-model-eval-new-data \
    --region=${REGION} \
    --topic=projects/${PROJECT_ID}/topics/${TOPIC} \
    --build-config=model-eval/cloudbuild-gcs-deploy.yaml \
    --repository="projects/${PROJECT_ID}/locations/${REGION}/connections/${REPOSITORY_CONNECTION_NAME}/repositories/${REPOSITORY}" \
    --branch="main" \
    --substitutions='_EVENT_TYPE=$(body.message.attributes.eventType)','_BUCKET_ID=$(body.message.attributes.bucketId)','_OBJECT_ID=$(body.message.attributes.objectId)','_EVAL_IMAGE_TAG=us-docker.pkg.dev/gkebatchexpce3c8dcb/llm/validate:18c085a','_VLLM_IMAGE_TAG=vllm/vllm-openai:v0.5.2','_CLUSTER_NAME=mlp-kenthua','_MODEL_PATH=${_OBJECT_ID/\/tokenizer_config.json/}','_DATASET_BUCKET=kh-finetune-ds','_DATA_COMMIT=${_MODEL_PATH##*-}' \
    --subscription-filter='_EVENT_TYPE.matches("OBJECT_FINALIZE") && _OBJECT_ID.matches("(model-.*/experiment-.*/tokenizer_config.json)$") && _BUCKET_ID.matches("^kr-finetune$")'
```

# Batch Hyper Parameter Tuning Trigger
-
```
gcloud builds triggers create github \
    --name=model-hyperparam-deploy \
    --region=${REGION} \
    --repository="projects/${PROJECT_ID}/locations/${REGION}/connections/${REPOSITORY_CONNECTION_NAME}/repositories/${REPOSITORY}" \
    --branch-pattern="^main$" \
    --build-config="finetune-gemma/batch/cloudbuild-hyperparam.yaml" \
    --included-files="finetune-gemma/batch/params.env" \
    --substitutions='_IMAGE_URL=us-docker.pkg.dev/gkebatchexpce3c8dcb/llm/finetune:18c085a','_CLUSTER_NAME=mlp-kenthua','_EXPERIMENT=gemma2','_MODEL_BUCKET=kr-finetune','_MODEL_NAME=google/gemma-2-9b-it','_MODEL_PATH=model-data/model-gemma2-a100/experiment','_TRAINING_DATASET_BUCKET=kh-finetune-ds','_TRAINING_DATASET_PATH=dataset/output-a2aa2c3','_DATA_COMMIT=${_TRAINING_DATASET_PATH##*-}'
```