from locust import FastHttpUser, task

# gemma 1.1
#model_id = "/model-data/hyperparam/model-job-1"
# gemma 2
model_id = "/model-data/hyperparam-gemma2/model-job-1"
#model_id = "TheBloke/Mixtral-8x7B-Instruct-v0.1-GPTQ"
message1 = "I'm looking for comfortable cycling shorts for women, what are some good options?"
message2 = "Tell me about some tops for men, looking for different styles"

class TestUser(FastHttpUser):
    @task#(50)
    def test1(self):
        self.client.post(
            "/v1/chat/completions",
            json={
                "model": model_id,
                "messages": [
                    {
                    "role": "user",
                    "content": message1
                    }
                ],
                "temperature": 0.5,
                "top_k": 1.0,
                "top_p": 1.0,
                "max_tokens": 256
            },
            name="message1"
        )

    # @task(50)
    # def test2(self):
    #     self.client.post(
    #         "/v1/chat/completions",
    #         json={
    #             "model": model_id,
    #             "messages": [
    #                 {
    #                 "role": "user",
    #                 "content": message2
    #                 }
    #             ],
    #             "temperature": 0.5,
    #             "top_k": 1.0,
    #             "top_p": 1.0,
    #             "max_tokens": 256
    #         },
    #         name="message2"
    #     )
