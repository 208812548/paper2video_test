import os
from openai import OpenAI


client = OpenAI(
    api_key="sk-TQpuDvl1WS9ZK7dshDS8svsehGxfRWyb9DHL3MHrFuf2ZxEw",
    base_url="https://api.openai.com/v1"
)

resp = client.responses.create(
    model="gpt-4.1",
    input="你好"
)

print(resp.output[0].content[0].text)