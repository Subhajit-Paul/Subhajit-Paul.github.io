---
layout: post
title: How to build an LLM-powered chatbot in Python
subtitle: Practical Retrieval-Augmented Generation with Streamlit and LangChain
description: "Learn how to build a Retrieval-Augmented Generation (RAG) chatbot using Python, Streamlit, LangChain, and ChromaDB to eliminate LLM hallucinations."
image: "/assets/rag-chatbot.jpg"
tags: [langchain, streamlit, LLM, RAG]
---

# Giving an LLM a Memory: Building a RAG Chatbot

If you have ever asked a Large Language Model (LLM) a question about your personal files or recent events, you have likely seen it "hallucinate"—confidently stating facts that aren't true. This happens because models are frozen in time; they only know what they were trained on. 

To fix this, we don't necessarily need to retrain the model. Instead, we can give it a "library card." This approach is called **Retrieval-Augmented Generation (RAG)**. Instead of relying solely on its internal weights, the model looks up relevant snippets from your documents and uses them as context to answer your questions.

## How RAG Actually Works

Think of RAG as an open-book exam. When you ask a question, the system follows three main steps:

1.  **Retrieval**: It searches through a collection of documents to find paragraphs related to your query.
2.  **Augmentation**: It takes those paragraphs and "stuffs" them into the prompt along with your original question.
3.  **Generation**: The LLM reads the context and generates an answer based strictly on that information.

This method drastically reduces errors because the model is anchored to real data. To build this in Python, we use three main tools: **Streamlit** for the interface, **LangChain** to connect the logic, and a **Vector Database** (like ChromaDB) to store and search our documents.

## Setting Up the Tools

Before writing code, we need to ensure our environment is ready. We'll use `langchain` for orchestration and `chromadb` to handle our searchable "memory."

```python
# requirements.txt
streamlit==1.24.0
langchain==0.1.0
chromadb==0.4.15
sentence-transformers==2.2.2
openai==1.6.0
python-dotenv==1.0.0
```

## The Core Logic: The RAG Engine

The heart of the system is the `RAGChatbot` class. It needs to take raw text files, break them into manageable pieces, and turn them into "embeddings"—mathematical representations of meaning that a computer can search.

```python
import streamlit as st
from langchain_community.embeddings import HuggingFaceEmbeddings
from langchain_community.vectorstores import Chroma
from langchain_openai import ChatOpenAI
from langchain.chains import ConversationalRetrievalChain
from langchain_community.document_loaders import DirectoryLoader
from langchain.text_splitter import RecursiveCharacterTextSplitter

class RAGChatbot:
    def __init__(self):
        # We use HuggingFace for local embeddings to save on API costs
        self.embeddings = HuggingFaceEmbeddings(model_name="all-MiniLM-L6-v2")
        self.llm = ChatOpenAI(model="gpt-3.5-turbo", temperature=0)
        self.initialize_knowledge_base()
        
    def initialize_knowledge_base(self):
        # 1. Load your local text files
        loader = DirectoryLoader('./documents', glob="**/*.txt")
        documents = loader.load()
        
        # 2. Split documents into small chunks
        # Why? Because LLMs have a limit on how much text they can read at once.
        text_splitter = RecursiveCharacterTextSplitter(
            chunk_size=1000,
            chunk_overlap=200 # Overlap helps maintain context between chunks
        )
        splits = text_splitter.split_documents(documents)
        
        # 3. Create a searchable Vector Store
        self.vectorstore = Chroma.from_documents(
            documents=splits,
            embedding=self.embeddings,
            persist_directory="./chroma_db"
        )
        
        # 4. Set up the Retrieval Chain
        self.chain = ConversationalRetrievalChain.from_llm(
            llm=self.llm,
            retriever=self.vectorstore.as_retriever(search_kwargs={"k": 3}),
            return_source_documents=True
        )
```

## Creating a Chat Interface with Streamlit

Streamlit allows us to build a web app using only Python. We want to maintain a "session state" so the chatbot remembers what we said earlier in the conversation.

```python
def main():
    st.set_page_config(page_title="Personal Knowledge Assistant")
    st.title("Chat with your Documents")
    
    if "messages" not in st.session_state:
        st.session_state.messages = []
        st.session_state.chat_history = []

    # Display previous messages
    for message in st.session_state.messages:
        with st.chat_message(message["role"]):
            st.markdown(message["content"])

    # Handle user input
    if prompt := st.chat_input("Ask me anything about your files..."):
        st.session_state.messages.append({"role": "user", "content": prompt})
        
        with st.chat_message("user"):
            st.markdown(prompt)
            
        with st.chat_message("assistant"):
            # The chain takes the prompt and the previous history
            response = chatbot.chain({
                "question": prompt, 
                "chat_history": st.session_state.chat_history
            })
            answer = response['answer']
            st.markdown(answer)
            
            # Update history
            st.session_state.chat_history.append((prompt, answer))
            st.session_state.messages.append({"role": "assistant", "content": answer})
```

## Fine-Tuning the Retrieval

A common problem in RAG is "context poisoning"—when the retriever fetches irrelevant snippets that confuse the model. One way to solve this is by refining how we manage the **Context Window**.

If we send too much history to the model, we waste tokens and money. We can implement a simple "sliding window" to keep only the most recent part of the conversation:

```python
def prune_history(chat_history, max_turns=5):
    """Keep only the last few turns to stay within the model's limits."""
    return chat_history[-max_turns:]
```

Another trick is **Metadata Filtering**. If you know your query only concerns "Legal Documents," you can tell the retriever to ignore everything else, making the search much faster and more accurate.

## Why this matters

Building a RAG system is more than just a coding exercise; it's about making AI useful in specialized domains. Whether you are a researcher managing thousands of papers or a developer building a support bot, the ability to ground an LLM in specific, verifiable data is the key to moving beyond "chatbots that hallucinate" to "tools that work."

The field is moving fast. We are now seeing "Agentic RAG," where the AI can decide *when* it needs to look something up and *when* it can answer from memory. But before you get there, mastering the basics of retrieval and prompt augmentation is essential.

### Further Reading
- [LangChain Documentation](https://python.langchain.com/)
- [The Original RAG Paper (Lewis et al.)](https://arxiv.org/abs/2005.11401)
- [Streamlit Chat Elements](https://docs.streamlit.io/library/api-reference/chat)
