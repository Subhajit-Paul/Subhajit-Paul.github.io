---
layout: post
title: How to build a LLM powered chatbot in python?
subtitle: Building an Intelligent RAG-Powered Chatbot with Streamlit and LangChain
tags: [langchain, streamlit, LLM, RAG]
---

# Building an Intelligent RAG-Powered Chatbot with Streamlit and LangChain

In today's rapidly evolving landscape of conversational AI, the integration of Retrieval-Augmented Generation (RAG) with modern web frameworks has emerged as a powerful approach for creating context-aware, knowledge-grounded chatbots. This article explores the implementation of a sophisticated chatbot system that leverages Streamlit for the user interface, LangChain for orchestration, and RAG for enhanced response generation.

## Understanding the Core Components

### Retrieval-Augmented Generation (RAG)

RAG represents a significant advancement in language model applications, combining the flexibility of generative AI with the accuracy and reliability of retrieval-based systems. Unlike traditional approaches that rely solely on a model's trained parameters, RAG dynamically incorporates relevant information from a knowledge base during inference, resulting in more accurate and verifiable responses.

The RAG architecture consists of two primary components:
1. A retriever that identifies and fetches relevant documents from a knowledge base
2. A generator that synthesizes these documents with the user query to produce coherent, contextually appropriate responses

### Streamlit: The Frontend Framework

Streamlit has revolutionized how data scientists and ML engineers build web applications. Its declarative syntax and Python-first approach make it ideal for creating interactive chatbot interfaces. The framework handles state management, user input processing, and real-time updates with minimal boilerplate code.

### LangChain: The Orchestration Layer

LangChain serves as the backbone of our chatbot system, providing essential abstractions for:
- Document loading and preprocessing
- Vector store management
- Prompt engineering
- Model interaction
- Response generation

## Implementation Architecture

### Setting Up the Development Environment

First, let's establish our project environment with the necessary dependencies:

```python
# requirements.txt
streamlit==1.24.0
langchain==0.0.284
chromadb==0.4.15
sentence-transformers==2.2.2
python-dotenv==1.0.0
openai==0.28.0
```

### Core Application Structure

Here's the basic structure of our RAG-powered chatbot:

```python
import streamlit as st
from langchain.embeddings import HuggingFaceEmbeddings
from langchain.vectorstores import Chroma
from langchain.chat_models import ChatOpenAI
from langchain.chains import ConversationalRetrievalChain
from langchain.document_loaders import DirectoryLoader
from langchain.text_splitter import RecursiveCharacterTextSplitter

class RAGChatbot:
    def __init__(self):
        self.embeddings = HuggingFaceEmbeddings()
        self.llm = ChatOpenAI(temperature=0.7)
        self.initialize_knowledge_base()
        
    def initialize_knowledge_base(self):
        # Load and process documents
        loader = DirectoryLoader('./documents', glob="**/*.txt")
        documents = loader.load()
        
        # Split documents into chunks
        text_splitter = RecursiveCharacterTextSplitter(
            chunk_size=1000,
            chunk_overlap=200
        )
        splits = text_splitter.split_documents(documents)
        
        # Create vector store
        self.vectorstore = Chroma.from_documents(
            documents=splits,
            embedding=self.embeddings
        )
        
        # Initialize retrieval chain
        self.chain = ConversationalRetrievalChain.from_llm(
            llm=self.llm,
            retriever=self.vectorstore.as_retriever(),
            return_source_documents=True
        )
```

### Streamlit Interface Implementation

The user interface is implemented using Streamlit's components:

```python
def create_ui():
    st.title("RAG-Powered Knowledge Assistant")
    
    # Initialize session state
    if "messages" not in st.session_state:
        st.session_state.messages = []
        st.session_state.chat_history = []
    
    # Display chat history
    for message in st.session_state.messages:
        with st.chat_message(message["role"]):
            st.markdown(message["content"])
    
    # Chat input
    if prompt := st.chat_input("What would you like to know?"):
        st.session_state.messages.append({"role": "user", "content": prompt})
        
        with st.chat_message("user"):
            st.markdown(prompt)
            
        with st.chat_message("assistant"):
            response = chatbot.get_response(prompt, st.session_state.chat_history)
            st.markdown(response)
            
        st.session_state.messages.append({"role": "assistant", "content": response})
```

## Advanced Features and Optimizations

### Context Window Management

One crucial aspect of RAG systems is managing the context window effectively. Here's an implementation of a sliding window approach:

```python
def manage_context_window(self, chat_history, max_tokens=3000):
    total_tokens = 0
    managed_history = []
    
    for query, response in reversed(chat_history):
        estimated_tokens = len(query.split()) + len(response.split())
        if total_tokens + estimated_tokens > max_tokens:
            break
        managed_history.append((query, response))
        total_tokens += estimated_tokens
    
    return list(reversed(managed_history))
```

### Document Preprocessing Pipeline

Implementing a robust document preprocessing pipeline is crucial for effective retrieval:

```python
def preprocess_documents(self, documents):
    # Remove boilerplate content
    cleaned_docs = [self.remove_boilerplate(doc) for doc in documents]
    
    # Deduplicate similar content
    unique_docs = self.deduplicate_content(cleaned_docs)
    
    # Extract key information
    processed_docs = []
    for doc in unique_docs:
        metadata = self.extract_metadata(doc)
        processed_docs.append(Document(
            page_content=doc.page_content,
            metadata={**doc.metadata, **metadata}
        ))
    
    return processed_docs
```

## Performance Optimization and Scaling

### Vector Store Optimization

For production deployments, consider these optimizations for the vector store:

```python
from langchain.vectorstores import Chroma
from langchain.embeddings import HuggingFaceEmbeddings

class OptimizedVectorStore:
    def __init__(self):
        self.embedding_function = HuggingFaceEmbeddings(
            model_name="all-MiniLM-L6-v2",
            model_kwargs={'device': 'cuda'}
        )
        self.vector_store = Chroma(
            persist_directory="./vector_store",
            embedding_function=self.embedding_function,
            collection_metadata={"hnsw:space": "cosine"}
        )
```

### Caching and Response Generation

Implement caching to improve response times:

```python
@st.cache_data(ttl=3600)
def get_cached_response(query_hash, chat_history_hash):
    return stored_responses.get((query_hash, chat_history_hash))

def generate_response(self, query, chat_history):
    query_hash = hash(query)
    chat_history_hash = hash(str(chat_history))
    
    # Check cache first
    cached_response = get_cached_response(query_hash, chat_history_hash)
    if cached_response:
        return cached_response
    
    # Generate new response if not in cache
    response = self.chain({"question": query, "chat_history": chat_history})
    
    # Store in cache
    store_response(query_hash, chat_history_hash, response)
    
    return response
```

## Deployment and Production Considerations

### Load Balancing and Scaling

For production deployments, implement load balancing and scaling strategies:

```python
from concurrent.futures import ThreadPoolExecutor
import queue

class LoadBalancedRAGChatbot:
    def __init__(self, num_workers=3):
        self.request_queue = queue.Queue()
        self.workers = [RAGChatbot() for _ in range(num_workers)]
        self.executor = ThreadPoolExecutor(max_workers=num_workers)
    
    def process_request(self, worker_id, request):
        return self.workers[worker_id].generate_response(**request)
    
    def handle_request(self, query, chat_history):
        worker_id = hash(query) % len(self.workers)
        request = {"query": query, "chat_history": chat_history}
        
        future = self.executor.submit(
            self.process_request,
            worker_id,
            request
        )
        return future.result()
```

## Conclusion

Building a RAG-powered chatbot with Streamlit and LangChain represents a powerful approach to creating intelligent conversational systems. The combination of Streamlit's user-friendly interface, LangChain's robust orchestration capabilities, and RAG's dynamic knowledge integration provides a solid foundation for building sophisticated AI applications.

As the field continues to evolve, we can expect to see further improvements in areas such as:
- More efficient retrieval algorithms
- Better context window management
- Enhanced response generation techniques
- Improved vector store optimizations

The key to success lies in carefully balancing these components while maintaining focus on the end-user experience and system performance.

## References

[LangChain Documentation](https://python.langchain.com/docs/get_started/introduction)
[Streamlit Documentation](https://docs.streamlit.io)
[RAG: Neural Information Retrieval Enhanced with Generation](https://arxiv.org/abs/2005.11401)
[Chroma Vector Store Documentation](https://docs.trychroma.com/)