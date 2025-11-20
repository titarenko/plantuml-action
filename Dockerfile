FROM eclipse-temurin:11-jre-jammy

ARG PLANTUML_VERSION=1.2025.10

# Install dependencies
RUN apt-get update && \
    apt-get install -y \
    curl \
    graphviz \
    && rm -rf /var/lib/apt/lists/*

# Download and install PlantUML
RUN curl -L "https://github.com/plantuml/plantuml/releases/download/v${PLANTUML_VERSION}/plantuml-${PLANTUML_VERSION}.jar" \
    -o /opt/plantuml.jar && \
    java -jar /opt/plantuml.jar -version && \
    echo "${PLANTUML_VERSION}" > /opt/plantuml_version.txt

# Create plantuml wrapper script
RUN echo '#!/bin/bash' > /usr/local/bin/plantuml && \
    echo 'java -jar /opt/plantuml.jar "$@"' >> /usr/local/bin/plantuml && \
    chmod +x /usr/local/bin/plantuml

# Copy the entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
