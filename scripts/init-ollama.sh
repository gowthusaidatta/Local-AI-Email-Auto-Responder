#!/bin/sh
set -e

echo "Waiting for Ollama service to be fully ready..."
sleep 5

MAX_RETRIES=3
ATTEMPT=0

while [ $ATTEMPT -lt $MAX_RETRIES ]; do
  ATTEMPT=$((ATTEMPT + 1))
  echo "Pulling llama3:8b model (attempt $ATTEMPT of $MAX_RETRIES)..."
  if OLLAMA_HOST=${OLLAMA_HOST:-http://ollama:11434} ollama pull llama3:8b; then
    echo "Pull succeeded."
    break
  else
    echo "Pull attempt $ATTEMPT failed."
    if [ $ATTEMPT -eq $MAX_RETRIES ]; then
      echo "ERROR: Failed to pull llama3:8b after $MAX_RETRIES attempts."
      exit 1
    fi
    sleep 10
  fi
done

echo "Verifying model is available..."
OLLAMA_HOST=${OLLAMA_HOST:-http://ollama:11434} ollama list

echo "Ollama initialization complete."
