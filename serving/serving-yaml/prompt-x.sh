USER_PROMPT="I'm looking for comfortable cycling shorts for women, what are some good options?"
USER_PROMPT=$2
#P="<start_of_turn>user\nI'm looking for heavily broidered saree with flower patterns, tell me more<end_of_turn>\n<start_of_turn>model\nThe Pratami Fashion Embroidered Bollywood Georgette Sari is a good option, it's made of georgette and has a beautiful flower pattern with embroidery.  \n Product Name: Pratami Fashion Embroidered Bollywood Georgette Sari\nProduct Category: Indian Traditional\nProduct Details:\n- Pattern: Embroidered\n- Occasion: Casual\n- Fabric: Georgette\n- Type: Bollywood\n- Blouse Piece: Yes\n- Ideal For: Women's\n\n- Color: Multicolor\n- Style Code: PMB0000071\n\n\n- Product Video: https://youtube.com/watch?v=Q1-47Q2-5-8\n\n\n\n- Design: Indian Traditional\n- Embroidery: Machine Embroidery\n- Blouse Piece: Yes\n- Fabric: Georgette\n- Type: Bollywood\n- Pattern: Embroidered\n- Ideal For: Women's\n- Occasion: Casual\n- Color: Multicolor\n- Style Code: PMB0000071\n\n\n\n- Sleeve: Full Sleeve\n- Number of Contents in Sales Package: Pack of 1\n- Fabric: Georgette\n- Type: Bollywood\n-"

curl -X POST http://localhost:$1/generate \
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