FROM ubuntu:24.04

RUN apt update && apt install -y nodejs npm curl git jq

ARG TODAY
RUN echo "Updating image on: $TODAY"

RUN npm install -g @anthropic-ai/claude-code

RUN mkdir -p /home/user/workspace && chmod -R 777 /home/user
ENV HOME=/home/user
ENV PATH="$HOME/.cargo/bin:$PATH"

# Claude Code is smart enough to read local Rust documentation, so we want to
# have that in place.
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs -o rustup.sh && sh rustup.sh -y && rm rustup.sh

COPY exec-claude-code.sh /home/user/claude-manager/exec-claude-code.sh

WORKDIR /home/user/workspace

ENTRYPOINT ["bash", "/home/user/claude-manager/exec-claude-code.sh"]
