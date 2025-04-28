FROM ubuntu:24.04

RUN apt update && apt install -y nodejs npm jq && npm install -g @anthropic-ai/claude-code

WORKDIR /claude-manager

COPY exec-claude-code.sh .

WORKDIR /workspace

ENTRYPOINT ["bash", "/claude-manager/exec-claude-code.sh"]
