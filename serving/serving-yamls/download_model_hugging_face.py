#Download a model using hugging face hub
from huggingface_hub import snapshot_download
model_id = "<your_model_id>" # eg: google/gemma-1.1-7b-it
token = "<your-hugging-face-token>"
snapshot_download(repo_id=model_id, local_dir=f"/tmp/{model_id}", local_dir_use_symlinks=False, token=token, resume_download=True, ignore_patterns=[".git*", ".huggingface/**"])