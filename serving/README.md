# Guide for standalone and distributed inferencing on GKE (Google Kubernetes Engine)

There are three common strategies for inference on vLLM:

- Single GPU (no distributed inference)
- Single-Node Multi-GPU (tensor parallel inference)
- Multi-Node Multi-GPU 

In this guide, you would serve a Gemma large language model (LLM) using graphical processing units (GPUs) on Google Kubernetes Engine (GKE) with the vLLM serving framework with the above mentioned deployment strategies.You can choose to swap the Gemma model with any other fine-tuned or instruction based model for inference on GKE.

By the end of this guide, you should be able to perform the following steps:

1. Prepare your environment with a GKE cluster in Standard mode(using ML playground).
2. Deploy a vLLM container to your cluster.
3. Use vLLM to serve the Gemma7B model through curl and a web chat interface.
4. View Production metrics for your model serving on GKE

## Single GPU (no distributed inference)

If your model fits in a single GPU, you probably don’t need to use distributed inference. Just use the single GPU to run the inference.



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




## Single-Node Multi-GPU (tensor parallel inference):

If your model is too large to fit in a single GPU, but it can fit in a single node with multiple GPUs, you can use tensor parallelism. The tensor parallel size is the number of GPUs you want to use. For example, if you have 4 GPUs in a single node, you can set the tensor parallel size to 4.

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