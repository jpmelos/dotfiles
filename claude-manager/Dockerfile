FROM ubuntu:24.04

RUN mkdir -p /home/user/workspace
ENV HOME=/home/user
ENV PATH="$HOME/.cargo/bin:$PATH"

RUN apt update && apt install -y nodejs npm curl git jq

RUN npm install -g @anthropic-ai/claude-code

# Claude Code is smart enough to read local Rust documentation, so we want to
# have that in place.
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs -o rustup.sh && sh rustup.sh -y && rm rustup.sh

COPY exec-claude-code.sh /home/user/claude-manager/exec-claude-code.sh

RUN chmod -R 777 /home/user

WORKDIR /home/user/workspace

ENTRYPOINT ["bash", "/home/user/claude-manager/exec-claude-code.sh"]
