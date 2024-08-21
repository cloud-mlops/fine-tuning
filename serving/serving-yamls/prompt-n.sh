# Replace USER_PROMPT and URL with your own values.
# model: folder location of the model in the deployed LLM pod

USER_PROMPT="I'm looking for comfortable cycling shorts for women, what are some good options?"

curl http://vllm-openai:8000/v1/chat/completions \
    -H "Content-Type: application/json" \
    -d '{
        "model": "/data/models/model-gemma2-a100/experiment-a2aa2c3it1",
        "messages": [
            {"role": "user", "content": "${USER_PROMPT}"}],
             "temperature": 0.70,
             "top_p": 1.0,
             "top_k": 1.0,
             "max_tokens": 256
    }'