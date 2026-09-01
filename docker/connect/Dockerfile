FROM quay.io/debezium/connect:3.6

USER root

RUN mkdir -p /kafka/connect/oracle-drivers

COPY drivers/ojdbc11.jar /kafka/connect/oracle-drivers/ojdbc11.jar

USER kafka