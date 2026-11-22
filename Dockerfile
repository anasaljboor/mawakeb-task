FROM maven:3.9.11-eclipse-temurin-17 AS build
WORKDIR /src
COPY pom.xml .
RUN --mount=type=cache,target=/root/.m2 mvn -B -q dependency:go-offline
COPY src ./src
RUN --mount=type=cache,target=/root/.m2 \
    mkdir -p target/surefire-reports && \
    (mvn -B package; echo $? > target/exit-code)

FROM scratch AS test-results
COPY --from=build /src/target/surefire-reports/ /

FROM build AS verified
RUN test "$(cat target/exit-code)" = "0"

FROM alpine:3.24.2 AS runtime
RUN apk upgrade --no-cache && \
    apk add --no-cache openjdk17-jre-headless && \
    addgroup -S -g 10001 app && adduser -S -u 10001 -G app app
WORKDIR /app
COPY --from=verified /src/target/simple-java-app-1.0.0.jar app.jar
USER 10001:10001
EXPOSE 8080
ENV JAVA_TOOL_OPTIONS="-XX:MaxRAMPercentage=75 -Djava.io.tmpdir=/tmp"
ENTRYPOINT ["java","-jar","/app/app.jar"]
