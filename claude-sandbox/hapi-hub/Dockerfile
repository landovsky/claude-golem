FROM node:22-slim

# Detect arch and install hapi with its platform-specific binary together
RUN ARCH=$(uname -m | sed 's/aarch64/arm64/; s/x86_64/x64/') && \
    npm install -g @twsxtd/hapi @twsxtd/hapi-linux-${ARCH}

ENV HAPI_LISTEN_HOST=0.0.0.0
ENV HAPI_LISTEN_PORT=3006

EXPOSE 3006

VOLUME /root/.hapi

CMD ["hapi", "hub"]
