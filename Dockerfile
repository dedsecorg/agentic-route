FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y iproute2 jq socat ca-certificates && rm -rf /var/lib/apt/lists/*
COPY bin/agentic-route /usr/local/bin/agentic-route
COPY lib/core.sh /usr/local/lib/agentic-route/core.sh
RUN chmod +x /usr/local/bin/agentic-route
ENTRYPOINT ["/usr/local/bin/agentic-route"]
CMD ["status"]
