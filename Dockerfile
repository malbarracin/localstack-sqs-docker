FROM eclipse-temurin:21-jre-alpine

LABEL maintainer="DevOps Forus <devops@forus.cl>"

RUN apk update && apk add tzdata && apk add bash && apk upgrade

RUN cp /usr/share/zoneinfo/America/Santiago /etc/localtime
RUN echo "America/Santiago" > /etc/timezone
RUN date

ARG JAR_FILE=target/*.jar

ADD ${JAR_FILE} app.jar

ENTRYPOINT ["java","-XX:MaxRAMPercentage=75","-Djava.security.egd=file:/dev/./urandom","-jar","/app.jar"]
