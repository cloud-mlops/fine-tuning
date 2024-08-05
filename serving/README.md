# Guide for standalone and distributed inferencing on GKE (Google Kubernetes Engine)

[ Place holder for concept diagram]
This exercise assumes you have a fine-tuned model, that we would like to serve on GKE.
If you have followed the previous steps for dataprep and finetune you would have a model store in the GCS bucket in your GCP Project.

### A quick brief on Inference on VLLM.

There are three common strategies for inference on vLLM:

- Single GPU (no distributed inference)
- Single-Node Multi-GPU (tensor parallel inference)
- Multi-Node Multi-GPU 

In this guide, you would serve a Gemma large language model (LLM) using graphical processing units (GPUs) on Google Kubernetes Engine (GKE) with the vLLM serving framework with the above mentioned deployment strategies.You can choose to swap the Gemma model with any other fine-tuned or instruction based model for inference on GKE.

By the end of this guide, you should be able to perform the following steps:

1. Prepare your environment with a GKE cluster in Standard mode(using ML playground).
2. Create a Persistent Disk for the LLM model weights.
2. Deploy a vLLM container to your cluster to host your model.
3. Use vLLM to serve the Gemma7B model through curl and a web chat interface.
4. View Production metrics for your model serving on GKE
5. Use custom metrics and HPA to scale your model deployments(instances) on GKE.

### Prerequisites
1. The ML Platform [Playground]( https://github.com/GoogleCloudPlatform/ai-on-gke/tree/ml-platform-dev/best-practices/ml-platform/examples/platform/playground) must be deployed
2. Data Set output from the [Data Preparation example](https://github.com/GoogleCloudPlatform/ai-on-gke/tree/ml-platform-dev/best-practices/ml-platform/examples/use-case/datapreparation/gemma-it)
3. Fine tune or other model available ready to be served.If you have been following the [fine tuning exercise with gemma model](https://github.com/GoogleCloudPlatform/ai-on-gke/tree/ml-platform-dev/best-practices/ml-platform/examples/use-case/finetuning/pytorch), a model artifact would be availble to use in [your model artifacts GCS bucket](https://github.com/GoogleCloudPlatform/ai-on-gke/tree/ml-platform-dev/best-practices/ml-platform/examples/use-case/finetuning/pytorch)
4. Set these Enviorment variables.

        ```
        PROJECT_ID=<your-project-id>
        PROJECT_NUMBER=$(gcloud projects describe ${PROJECT_ID} --format="value(projectNumber)")
        V_MODEL_BUCKET=<model-artifacts-bucket>
        CLUSTER_NAME=<your-gke-cluster>
        NAMESPACE=ml-serve
        KSA=<k8s-service-account>
        HF_TOKEN=<your-Hugging-Face-account-token>
        MODEL_ID=<your-model-id>
        REGION=<your-region>
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

### Create a Persistent Disk for the LLM model weights

If you already have LLM model and weights uploaded to a bucket location( as mentioned above) then skip this creation of bucket.

#### Upload the model and weights to GCS bucket.

1. Create a GCS bucket in the same region as your GKE cluster.

        ```
        gsutil mb gs://${V_MODEL_BUCKET} --region ${REGION}
       

        Grant permission to kubernetes service account in cluster to access the storage bucket to view model weights

        ```
        gcloud storage buckets add-iam-policy-binding "gs://$BUCKET_NAME" \
        --member "principal://iam.googleapis.com/projects/"$PROJECT_NUMBER"/locations/global/workloadIdentityPools/${PROJECT_ID}.svc.id.goog/subject/ns/$NAMESPACE/sa/$KSA" \
        --role "roles/storage.objectViewer"

        ```

        ```
        gcloud storage buckets update gs://$BUCKET_NAME --uniform-bucket-level-access
        ```

   2. Download the model to your local environment. For example, here we are downloading a model from hugging face.

        In your local enviornment, install hugging face hub using pip:
        ```
        pip3 install huggingface_hub
        ```
        Download the model using python3

        ```
        python3 serving-yamls/download_model_hugging_face.py
        ```

    3. Upload the model to the GCS bucket

        ```
        MODEL_ID=<your_model_id> # eg: google/gemma-1.1-7b-it
        MODEL_ORG="$(dirname "$MODEL_ID")"      
        gsutil cp -r /tmp/models/$MODEL_ORG/  gs://$BUCKET_NAME
        ```
        


   



       

#### Deploy a vLLM container to your cluster.

Create a Kubernetes secret for Hugging Face credentials
Deploy the vLLM container to serve the Gemma model you want to use.

#### Use vLLM to serve the Gemma7B model through curl and a web chat interface.

Serve the model

#### Production Metrics
vLLM exposes a number of metrics that can be used to monitor the health of the system. These metrics are exposed via the /metrics endpoint on the vLLM OpenAI compatible API server.

The following metrics are exposed:

```


```

#### Custom metrics for Single GPU Deployment.


## Multi-Node Multi-GPU (tensor parallel plus pipeline parallel inference):
If your model is too large to fit in a single node, you can use tensor parallel together with pipeline parallelism. The tensor parallel size is the number of GPUs you want to use in each node, and the pipeline parallel size is the number of nodes you want to use. For example, if you have 16 GPUs in 2 nodes (8GPUs per node), you can set the tensor parallel size to 8 and the pipeline parallel size to 2.

Note : In short, you should increase the number of GPUs and the number of nodes until you have enough GPU memory to hold the model. The tensor parallel size should be the number of GPUs in each node, and the pipeline parallel size should be the number of nodes.

#### Prepare your environment with a GKE cluster in Standard mode.

Follow along the steps provide in this READme to create a playground cluster for ML platform on GKE.
        https://github.com/GoogleCloudPlatform/ai-on-gke/tree/ml-platform-dev/best-practices/ml-platform/examples/platform/playground

#### Deploy a vLLM container to your cluster.

Create a Kubernetes secret for Hugging Face credentials
Deploy the vLLM container to serve the Gemma model you want to use.

#### Use vLLM to serve the Gemma7B model through curl and a web chat interface.

Serve the model

#### Production Metrics
vLLM exposes a number of metrics that can be used to monitor the health of the system. These metrics are exposed via the /metrics endpoint on the vLLM OpenAI compatible API server.

The following metrics are exposed:

```


```

#### Custom metrics for Single GPU Deployment.
