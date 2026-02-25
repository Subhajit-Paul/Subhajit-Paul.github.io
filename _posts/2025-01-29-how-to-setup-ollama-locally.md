---
layout: post
title: How to setup Ollama locally?
subtitle: Running Large Language Models in Your Own Room
tags: [LLM, OLLAMA, LLAMA3.3]
---

# Why Run AI Locally?

In the world of AI, we often hear about "the cloud." But what if you could run a powerful model on your own laptop, without an internet connection? This is where **Ollama** comes in.

Ollama is a simple tool that lets you download and run Large Language Models (LLMs) locally. It's built on a fast C++ core but wrapped in an interface as easy to use as a web browser.

## The Benefits of Local AI

Running a model like **Llama 3** or **Mistral** on your own hardware has three big advantages:
1.  **Privacy**: Your data never leaves your computer. If you have sensitive documents or personal ideas, you don't have to worry about them being used to train a company's next model.
2.  **No Costs**: You don't have to pay per token. Once you've downloaded the model, you can use it as much as you want for free.
3.  **No Latency**: You aren't waiting for a server across the world to respond. If your GPU is fast, the AI is fast.

## How Ollama Actually Works

Ollama is built with **Go** and handles the heavy lifting of:
- **Model Management**: Downloading and updating weights (the "brains" of the model).
- **Inference**: Using your computer's GPU or CPU to generate text.
- **API Access**: Giving you a simple URL (`http://localhost:11434`) that other apps can use to talk to your local AI.

## Getting Started: A Simple Guide

Ollama is designed to be as easy to install as any other app.

```bash
# 1. Install Ollama (on Linux)
curl -fsSL https://ollama.com/install.sh | sh

# 2. Start the service
ollama serve

# 3. Download and run a model
ollama run llama3.1
```

Once it's running, you can just start typing in your terminal to chat with the model!

## Customizing Your AI with "Modelfiles"

Just like Docker has Dockerfiles, Ollama has **Modelfiles**. These let you customize how the AI behaves. For example, if you want a model that acts as a code reviewer:

```dockerfile
# Create a file named 'Modelfile'
FROM llama3.1
PARAMETER temperature 0.2 # Lower temperature = more focused, less creative
SYSTEM "You are a professional software engineer. Only review Python code."
```

Then you can create your custom model:
`ollama create my-code-reviewer -f Modelfile`

## Using the API in Python

Ollama's API is very simple to use. Here's how you can ask a question from a Python script:

```python
import requests
import json

def ask_local_ai(prompt):
    url = "http://localhost:11434/api/generate"
    data = {
        "model": "llama3.1",
        "prompt": prompt,
        "stream": False # Set to True if you want to see words as they are generated
    }
    
    response = requests.post(url, json=data)
    return json.loads(response.text)['response']

# Example usage
print(ask_local_ai("What is the best way to learn Python?"))
```

## Performance: What Hardware Do You Need?

Running AI locally requires a lot of memory. A common trick is **Quantization**, which compresses the model so it fits on normal computers.

Here's a rough guide to the RAM you'll need:
- **Llama 3 8B (Compressed)**: ~8GB RAM (Standard laptops)
- **CodeLlama 13B**: ~16GB RAM (Gaming laptops)
- **Large Models (70B+)**: 64GB+ RAM (Workstations)

If you have an **NVIDIA GPU** or a **Mac with Apple Silicon**, Ollama will automatically use it to make the AI much faster.

## Real-World Use Case: Private Document Review

Imagine you have a 50-page contract you need to summarize. Uploading it to a cloud provider might be against your company's policy. With Ollama, you can run a local model and ask:
`"Summarize the liability section of this contract."`

You get the answer in seconds, and your data stays completely private.

## The Future of Local AI

The world of local LLMs is moving incredibly fast. We are seeing smaller and smarter models every month. Ollama is at the center of this movement, making it possible for anyone to have a powerful AI assistant sitting right on their desk.

As hardware gets better and models get more efficient, the need for "the cloud" for daily AI tasks will only decrease. Local AI is here to stay.

### References
- [Ollama Official Website](https://ollama.com/)
- [Llama 3 on Hugging Face](https://huggingface.co/meta-llama/Meta-Llama-3-8B)
- [How Quantization Works](https://huggingface.co/docs/optimum/concept_guides/quantization)
