# Oracle to RisingWave Real-Time CDC Streaming Pipeline

> A low-latency, event-driven Change Data Capture (CDC) pipeline capturing Oracle DB transactions via LogMiner and streaming them to RisingWave and Apache Superset using Debezium and Apache Kafka.

---

## Overview

### Purpose & Objective
This project builds a production-grade, open-source real-time Change Data Capture (CDC) and stream processing architecture. The primary objective is to capture row-level database modification events (DML) from an Oracle transactional database without application code changes, stream them through a message broker, maintain incrementally updated materialized views, and expose live analytics via dashboards.

### Problem Solved
Traditional batch-based ETL processes introduce significant data latency, heavy query loads on transactional source databases during extract windows, and delayed decision-making capabilities. This solution provides continuous, low-latency streaming analytics while minimizing read overhead on the source Oracle database.

---

## Architecture

The system follows an end-to-end streaming data architecture:

1. **Source Tier**: Oracle DB logs DML transactions to Redo Logs.
2. **CDC Capture Tier**: Debezium Connect uses Oracle LogMiner to mine transaction logs without agents.
3. **Event Broker Tier**: Apache Kafka (KRaft mode) buffers CDC events in dedicated topics.
4. **Stream Processing Tier**: RisingWave consumes raw Kafka events and maintains real-time Materialized Views using SQL.
5. **Serving & Visualization Tier**: Apache Superset executes queries against RisingWave materialized views to render real-time dashboards.

```mermaid
graph TD
    subgraph Source ["Source Tier"]
        Oracle["Oracle DB (XE)<br/>(Redo / Archive Logs)"]
    end

    subgraph CDC ["Change Data Capture Tier"]
        LogMiner["Oracle LogMiner Engine"]
        Debezium["Debezium Kafka Connect<br/>(v3.6 / JDBC Driver)"]
    end

    subgraph Broker ["Event Streaming Tier"]
        Kafka["Apache Kafka Broker<br/>(KRaft Mode :9092)"]
        Kafdrop["Kafdrop UI<br/>(:9000)"]
    end

    subgraph Processing ["Stream Processing & Serving Tier"]
        RisingWave["RisingWave<br/>(Materialized Views)"]
        Postgres["PostgreSQL<br/>(Superset Metadata)"]
        Superset["Apache Superset<br/>(BI Dashboards)"]
    end

    Oracle -->|1. Writes DML to Redo Logs| LogMiner
    LogMiner -->|2. Extracts Change Vectors| Debezium
    Debezium -->|3. Publishes JSON CDC Events| Kafka
    Kafka -.->|Inspect Topics| Kafdrop
    Kafka -->|4. Consumes Event Stream| RisingWave
    RisingWave -->|5. Serves SQL Queries| Superset
    Postgres -.->|Metadata Store| Superset