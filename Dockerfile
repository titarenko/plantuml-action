FROM openjdk:11-jre-slim

# Install dependencies
RUN apt-get update && \
    apt-get install -y \
    curl \
    graphviz \
    && rm -rf /var/lib/apt/lists/*

# Create directory for PlantUML
RUN mkdir -p /opt

# Copy the entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
