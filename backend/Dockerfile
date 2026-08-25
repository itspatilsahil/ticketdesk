# ---- Stage 1: build --------------------------------------------------
# Only this stage ever has a JDK or Maven in it. None of it survives
# into the final image (checklist item 3).
FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /app

# Copy pom first so dependency resolution is cached across builds that
# only change source code, not dependencies.
COPY pom.xml .
RUN mvn -B -q dependency:go-offline

COPY src ./src
RUN mvn -B -q clean package -DskipTests

# ---- Stage 2: runtime --------------------------------------------------
# JRE only (no compiler, no build tools), Alpine base to keep the image
# small. Runs as a dedicated non-root user (checklist item 2).
FROM eclipse-temurin:21-jre-alpine

RUN apk update && apk upgrade --no-cache

RUN addgroup -S ticketdesk && adduser -S ticketdesk -G ticketdesk
WORKDIR /app
COPY --from=build /app/target/ticketdesk-api.jar app.jar
RUN chown ticketdesk:ticketdesk app.jar
USER ticketdesk

EXPOSE 8080

ENV JAVA_OPTS="-XX:MaxRAMPercentage=75.0 -XX:+UseSerialGC"

ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]
