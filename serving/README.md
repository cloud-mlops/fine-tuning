# Guide for standalone and distributed inferencing on GKE (Google Kubernetes Engine)

This exercise assumes you have a fine-tuned model, that we would like to serve on GKE.
If you have followed the previous steps for dataprep and finetune you would have a model store in the GCS bucket in your GCP Project.

### A quick brief on Inference on VLLM.

There are three common strategies for inference on vLLM:

- Single GPU (no distributed inference)
- Single-Node Multi-GPU (tensor parallel inference)
- Multi-Node Multi-GPU 

In this guide, you would serve a fine-tuned Gemma large language model (LLM) using graphical processing units (GPUs) on Google Kubernetes Engine (GKE) with the vLLM serving framework with the above mentioned deployment strategies.You can choose to swap the Gemma model with any other fine-tuned or instruction based model for inference on GKE.

By the end of this guide, you should be able to perform the following steps:

                [ Place holder for concept diagram]

1. Prepare your ML Platform [Playground]( https://github.com/GoogleCloudPlatform/ai-on-gke/tree/ml-platform-dev/best-practices/ml-platform/examples/platform/playground).
2. Create a Persistent Disk for the LLM model weights.
2. Deploy a vLLM container to your cluster to host your model.
3. Use vLLM to serve the Gemma7B model through curl and a web chat interface.
4. View Production metrics for your model serving on GKE
5. Use custom metrics and HPA to scale your model deployments(instances) on GKE.

### Prerequisites
1. The ML Platform [Playground]( https://github.com/GoogleCloudPlatform/ai-on-gke/tree/ml-platform-dev/best-practices/ml-platform/examples/platform/playground) must be deployed
2. Data Set output from the [Data Preparation example](https://github.com/GoogleCloudPlatform/ai-on-gke/tree/ml-platform-dev/best-practices/ml-platform/examples/use-case/datapreparation/gemma-it)
3. Fine tune or other model available ready to be served.If you have been following the [fine tuning exercise with gemma model](https://<github.com/GoogleCloudPlatform/ai-on-gke/tree/ml-platform-dev/best-practices/ml-platform/examples/use-case/finetuning/pytorch), a model artifact would be availble to use in [your model artifacts GCS bucket](https://github.com/GoogleCloudPlatform/ai-on-gke/tree/ml-platform-dev/best-practices/ml-platform/examples/use-case/finetuning/pytorch)
4. Set these Enviorment variables.

```
PROJECT_ID=your-project-id>
PROJECT_NUMBER=$(gcloud projects describe ${PROJECT_ID} --format="value(projectNumber)")
V_MODEL_BUCKET=<model-artifacts-bucket>
CLUSTER_NAME=<your-gke-cluster>
NAMESPACE=ml-serve
KSA=<k8s-service-account>
HF_TOKEN=<your-Hugging-Face-account-token>
MODEL_ID=<your-model-id>
REGION=<your-region>
IMAGE_NAME=<your-image-name>
DISK_NAME=<your-disk-name>
```

## Single GPU (no distributed inference)

If your model fits in a single GPU, you probably don’t need to use distributed inference. Just use the single GPU to run the inference.
You can follow the steps similiar to the Single-Node Multi-GPU (tensor parallel inference)

## Single-Node Multi-GPU (tensor parallel inference):

If your model is too large to fit in a single GPU, but it can fit in a single node with multiple GPUs, you can use tensor parallelism. The tensor parallel size is the number of GPUs you want to use. For example, if you have 4 GPUs in a single node, you can set the tensor parallel size to 4.

#### Prepare your environment with a GKE cluster in Standard mode.

Follow along the steps provide in this README.md( https://github.com/GoogleCloudPlatform/ai-on-gke/tree/ml-platform-dev/best-practices/ml-platform/examples/platform/playground) to create a playground cluster for ML platform on GKE.

You can also re-use the cluster from previous fine-tuning and dataprep exercise as mentioned in pre-requistes.

From the CLI connect to the GKE cluster

```
gcloud container clusters get-credentials ${CLUSTER_NAME} --region $REGION
```

```
kubectl create ns ${NAMESPACE}
```

```
kubectl create sa ${KSA} -n ${NAMESPACE}
```

#### Create a Persistent Disk for the LLM model weights

If you already have LLM model and weights uploaded to a bucket location( as mentioned above) then skip creation of bucket.

##### Optional :  Upload the model and weights to GCS bucket.

Create a GCS bucket in the same region as your GKE cluster.

```
gcloud storage buckets create gs://${V_MODEL_BUCKET} --location ${REGION}
```

Grant permission to kubernetes service account in cluster to access the storage bucket to view model weights

```
gcloud storage buckets add-iam-policy-binding "gs://$V_MODEL_BUCKET" \
--member "principal://iam.googleapis.com/projects/"$PROJECT_NUMBER"/locations/global/workloadIdentityPools/${PROJECT_ID}.svc.id.goog/subject/ns/$NAMESPACE/sa/$KSA" \
--role "roles/storage.objectViewer"
```

Update the bucket access level to uniform.

```
gcloud storage buckets update "gs://$V_MODEL_BUCKET"  --uniform-bucket-level-access
```

Download the model to your local environment. For example, here we are downloading a model from hugging face.

In your local enviornment, install hugging face hub using pip :

```
pip3 install huggingface_hub
```

Download the model using python3 script.:

Note: The model_id that you provided in the script will be downloaded locally to your /tmp/models folder.

```
python3 serving-yamls/download_model_hugging_face.py
```

Upload the model to the GCS bucket.

```
MODEL_ID=<your_model_id> # eg: google/gemma-1.1-7b-it
MODEL_ORG="$(dirname "$MODEL_ID")"      
gsutil cp -r /tmp/models/$MODEL_ORG/  gs://$V_MODEL_BUCKET
```

##### Create PV, PVC and Persistent disk.

Loading model weights from Persistent Volume is one of solutions to load models faster on GKE cluster. In GKE, Persistent Volumes backed by GCP Persistent Disks can be mounted read-only simultaneously  by multiple nodes(ReadOnlyMany), this makes multiple pods access the model weights possible. 

1. Create a PVC for the model weights

```
kubectl apply -f serving-yamls/pvc_disk_image.yaml
```

2. Create a job downloading the models to the volume and review logs for successful completion.

```
sed -i -e "s|_YOUR_BUCKET_NAME_|${V_MODEL_BUCKET}|" serving-yamls/batch_job_download_model_on_pv_volume.yaml
kubectl create -f serving-yamls/batch_job_download_model_on_pv_volume.yaml
kubectl logs  module-download-job-ptdpt-6cq8r
```

Wait for the job to show completion.

```
module-download-job-sg6j7-4bxg4
```

3. Create the PV and PVC

```
PV_NAME="$(kubectl get pvc/block-pvc-model -o jsonpath='{.spec.volumeName}')"
```

```
DISK_REF="$(kubectl get pv "$PV_NAME"  -o jsonpath='{.spec.csi.volumeHandle}')"
```

```
gcloud compute images create model-weights-image --source-disk="$DISK_REF"
```

```
gcloud compute disks create models-fine-tune-disk-v1  --size=1TiB --type=pd-ssd --zone=<enter-your-zone> --image=model-weights-image
Note: Choose a zone based on cluster location and gpu availability
```

```
sed -i -e "s|_NAMESPACE_|${NAMESPACE}|" serving-yamls/pv_and_pvc.yaml
kubectl apply -f serving-yamls/pv_and_pvc.yaml
```

       
#### Deploy a vLLM container to your cluster.

Run the batch job to deploy model using persistent disk on GKE.

```
NAMESPACE=<your-inference-namespace>
ACCELERATOR_TYPE=<gpu-accelerator-type> #e.g nvidia-l4

sed -i -e "s|_NAMESPACE_|${NAMESPACE}|" serving-yamls/batch_job_model_deployment.yaml
sed -i -e "s|_ACCELERATOR_TYPE_|${ACCELERATOR_TYPE}|" serving-yamls/batch_job_model_deployment.yaml

```

```
kubectl create -f serving-yamls/model_deployment.yaml
kubectl describe pods vllm-openai-<replace-the-pod-name> -n ${NAMESPACE}
```

```
INFO:     Started server process [1]
INFO:     Waiting for application startup.
INFO:     Application startup complete.
INFO:     Uvicorn running on http://0.0.0.0:8000 (Press CTRL+C to quit)
```


#### Serve the deployed model through curl and a web chat interface.

You can run curl commands to test prompts for your LLM

ssh into the LLM pod 

```
kubectl exec -it vllm-openai-<your-pod-name> -n ml-serve -- bash
```

Run the curl prompt with your values

```
./servimg-yamls/prompt-n.sh
```

Optional : You can also deploy gradio chat interface to view the model chat interface.

```
sed -i -e "s|_NAMESPACE_|${NAMESPACE}|" serving-yamls/gradio.yaml
kubectl apply -f serving-yamls/gradio.yaml
```

#### Production Metrics
vLLM exposes a number of metrics that can be used to monitor the health of the system. These metrics are exposed via the /metrics endpoint on the vLLM OpenAI compatible API server.


```
kubectl exec -it vllm-openai-6cdc44d69-hrlkz -n ml-serve -- bash
curl http://vllm-openai:8000/metrics
```

#### View Production metrics for your model serving on GKE

You can configure monitoring of the metrics above using the [pod monitoring](https://cloud.google.com/stackdriver/docs/managed-prometheus/setup-managed#gmp-pod-monitoring)

```
kubectl apply -f serving-yamls/pod_monitoring.yaml
```

#### Import the vLLM metrics into cloud monitoring.


Cloud Monitoring provides an [importer](https://cloud.google.com/monitoring/dashboards/import-grafana-dashboards) that you can use to import dashboard files in the Grafana JSON format into Cloud Monitoring


1. Clone github repository 

```
git clone https://github.com/GoogleCloudPlatform/monitoring-dashboard-samples
```


2. Change to the directory for the dashboard importer:

```
cd monitoring-dashboard-samples/scripts/dashboard-importer
```

The dashboard importer includes the following scripts:

import.sh, which converts dashboards and optionally uploads the converted dashboards to Cloud Monitoring.

upload.sh, which uploads the converted dashboards—or any Monitoring dashboards—to Cloud Monitoring. The import.sh script calls this script to do the upload.



3. Import the dashboard

```
./import.sh ./grafana.json ${PROJECT_ID}
```

When you use the import.sh script, you must specify the location of the Grafana dashboards to convert. The importer creates a directory that contains the converted dashboards and other information.


### Run Batch inference on GKE

Once a model has completed fine-tuning and is deployed on GKE , its ready to run batch Inference pipeline.
In this example batch inference pipeline, we would first send prompts to the hosted fine-tuned model and then validate the results based on ground truth.

#### Prepare your environment


Set env variables.

```
PROJECT_ID=<your-project-id>
PROJECT_NUMBER=$(gcloud projects describe ${PROJECT_ID} --format="value(projectNumber)")
CLUSTER_NAME=<your-gke-cluster>
NAMESPACE=ml-serve
MODEL_PATH=<your-model-path>
BUCKET="<your dataset bucket name>"
DATASET_OUTPUT_PATH=""
ENDPOINT=<your-endpoint> # eg "http://vllm-openai:8000/v1/chat/completions"
KSA=<k8s-service-account> # Service account with work-load identity enabled
```

Create Service account.

```
NAMESPACE=ml-serve
kubectl create sa ${KSA} -n ${NAMESPACE}
```

Setup Workload Identity Federation access to read/write to the bucket for the inference batch data set

```
gcloud storage buckets add-iam-policy-binding gs://${BUCKET} \
    --member "principal://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${PROJECT_ID}.svc.id.goog/subject/ns/${NAMESPACE}/sa/${KSA}" \
    --role "roles/storage.objectUser"
```

```
gcloud storage buckets add-iam-policy-binding gs://${BUCKET} \
    --member "principal://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${PROJECT_ID}.svc.id.goog/subject/ns/${NAMESPACE}/sa/${KSA}" \
    --role "roles/storage.legacyBucketWriter"
```

#### Build the image of the source and execute batch inference job

Create Artifact Registry repository for your docker image

```
gcloud artifacts repositories create llm-inference-repository \
    --repository-format=docker \
    --location=us \
    --project=${PROJECT_ID} \
    --async

```

Set Docker Image URL

```
DOCKER_IMAGE_URL=us-docker.pkg.dev/${PROJECT_ID}/llm-inference-repository/validate:v1.0.0
```

Enable the Cloud Build APIs

```
gcloud services enable cloudbuild.googleapis.com --project ${PROJECT_ID}
```

Build container image using Cloud Build and push the image to Artifact Registry Modify cloudbuild.yaml to specify the image url

sed -i "s|IMAGE_URL|${DOCKER_IMAGE_URL}|" cloudbuild.yaml && \
gcloud builds submit . --project ${PROJECT_ID}

Get credentials for the GKE cluster

```
gcloud container fleet memberships get-credentials ${CLUSTER_NAME} --project ${PROJECT_ID}
```

Set variables for the inference job in model-eval.yaml

```
sed -i -e "s|IMAGE_URL|${DOCKER_IMAGE_URL}|" \
    -i -e "s|KSA|${KSA}|" \
    -i -e "s|V_BUCKET|${BUCKET}|" \
    -i -e "s|V_MODEL_PATH|${MODEL_PATH}|" \
    -i -e "s|V_DATASET_OUTPUT_PATH|${DATASET_OUTPUT_PATH}|" \
    -i -e "s|V_ENDPOINT|${ENDPOINT}|" \
    model-eval.yaml
```

Create the Job in the ml-team namespace using kubectl command

```
kubectl apply -f model-eval.yaml -n ${NAMESPACE}
```

You can review predictions result in file named `predictions.txt` .Sample file has been added to the repository.
The job will take approx 45 mins to execute.

### Run Benchmarks for inference

The model is ready to run the benchmarks for inference job. We can run few performance tests using locust.
Locust is an open source performance/load testing tool for HTTP and other protocols.
You can refer to the documentation to [set up](https://docs.locust.io/en/stable/installation.html) locust locally or deploy as a container on GKE.

We have created a sample [locustfile](https://docs.locust.io/en/stable/writing-a-locustfile.html) to run tests against our model using sample prompts which we tried earlier in the exercise.
Here is a sample ![graph](./serving-yamls/benchmarks/locust.py) to review.

If you have a local set up for locust. You can execute the tests using following :


```
cd benchmarks
$locust
```

You can update the service end point of model to LoadBalancer(type) to ensure you can reach the hosted model's endpoint outside the ml-serve namespace . You can access the model endpoint using correct [annotation](https://cloud.google.com/kubernetes-engine/docs/concepts/service-load-balancer#load_balancer_types)




### Inference at Scale

There are different metrics available that could be used to autoscale your inference workloads on GKE.

1. Server metrics: LLM inference servers vLLM provides workload-specific performance metrics. GKE simplifies scraping and autoscaling of workloads based on these server-level metrics. You can use these metrics to gain visibility into performance indicators like batch size, queue size, and decode latencies

In case of vLLM, [production metrics class](https://docs.vllm.ai/en/latest/serving/metrics.html) exposes a number of useful metrics whch GKE can use to autoscale inference metrics on.

```
vllm:num_requests_running : Number of requests currently running on GPU.
vllm:num_requests_waiting : Number of requests waiting to be processed
```

2. GPU metrics:

```
GPU Utilization (DCGM_FI_DEV_GPU_UTIL)	Measures the duty cycle, which is the amount of time that the GPU is active.
GPU Memory Usage (DCGM_FI_DEV_FB_USED)	Measures how much GPU memory is being used at a given point in time. This is useful for workloads that implement dynamic allocation of GPU memory.
```

3. CPU metrics: Since the inference workloads primarily rely on GPU resources , we don't recommend CPU and memory utilization as the only indicators of the amount of resources a job consumes.Therefore, using CPU metrics alone for autoscaling can lead to suboptimal performance and costs. 
 
HPA is an efficient way to ensure that your model servers scale appropriately with load. Fine-tuning the HPA settings is the primary way to align your provisioned hardware cost with traffic demands to achieve your inference server performance goals.

We recommend setting these HPA configuration options:

Stabilization window: Use this HPA configuration option to prevent rapid replica count changes due to fluctuating metrics. Defaults are 5 minutes for scale-down (avoiding premature downscaling) and 0 for scale-up (ensuring responsiveness). Adjust the value based on your workload's volatility and your preferred responsiveness.
Scaling policies: Use this HPA configuration option to fine-tune the scale-up and scale-down behavior. You can set the "Pods" policy limit to specify the absolute number of replicas changed per time unit, and the "Percent" policy limit to specify by the percentage change.












