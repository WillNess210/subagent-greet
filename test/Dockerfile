FROM node:24-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
      bash gawk python3 git ca-certificates curl jq \
 && rm -rf /var/lib/apt/lists/*

RUN npm install -g @anthropic-ai/claude-code

# Plugin source
COPY .claude-plugin /opt/subagent-greet/.claude-plugin
COPY skills        /opt/subagent-greet/skills
COPY scripts       /opt/subagent-greet/scripts
COPY hooks         /opt/subagent-greet/hooks
COPY README.md     /opt/subagent-greet/README.md

# Test entrypoint
COPY test/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh \
             /opt/subagent-greet/scripts/subagent-greet.sh \
             /opt/subagent-greet/hooks/session-start.sh

WORKDIR /workspace
ENTRYPOINT ["/entrypoint.sh"]
