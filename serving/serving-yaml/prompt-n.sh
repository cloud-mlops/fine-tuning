USER_PROMPT="I'm looking for comfortable cycling shorts for women, what are some good options?"

curl -X POST http://localhost:8000/generate \
  -H "Content-Type: application/json" \
  -d @- <<EOF #| jq -r .predictions[0]
{
    "prompt": "<start_of_turn>user\n${USER_PROMPT}<end_of_turn>\n<start_of_turn>model\n",
    "temperature": 0.70,
    "top_p": 1.0,
    "top_k": 1.0,
    "max_tokens": 256
}
EOF
#    "prompt": "<start_of_turn>user\n${USER_PROMPT}<end_of_turn>\n",
