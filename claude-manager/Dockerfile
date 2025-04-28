FROM ubuntu:24.04

RUN apt update && apt install -y nodejs npm jq && npm install -g @anthropic-ai/claude-code

RUN mkdir -p /home/user/workspace && chmod -R 777 /home/user

COPY exec-claude-code.sh /home/user/claude-manager/exec-claude-code.sh

WORKDIR /home/user/workspace

ENTRYPOINT ["bash", "/home/user/claude-manager/exec-claude-code.sh"]
