#!/bin/bash

# Check CDC payload from Kafka topic - Bash version
# Robust error handling and message parsing

TOPIC="oracle21.APPUSER.CDC_TEST"
KAFKA_CONTAINER="kafka"

echo "=========================================="
echo "Checking CDC Payload from Kafka"
echo "Topic: $TOPIC"
echo "=========================================="
echo ""

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    echo "ERROR: Docker is not installed or not in PATH" >&2
    exit 1
fi

# Check if Kafka container is running
if ! docker ps --filter "name=$KAFKA_CONTAINER" --format "{{.Names}}" | grep -q "^${KAFKA_CONTAINER}$"; then
    echo "ERROR: Kafka container '$KAFKA_CONTAINER' is not running" >&2
    exit 1
fi

echo "Reading messages from Kafka topic..."
echo ""

# Read messages from Kafka with proper error handling
OUTPUT=$(docker exec "$KAFKA_CONTAINER" \
    kafka-console-consumer \
    --bootstrap-server localhost:9092 \
    --topic "$TOPIC" \
    --from-beginning \
    --max-messages 10 \
    --timeout-ms 5000 \
    2>&1)

EXIT_CODE=$?

if [ -z "$OUTPUT" ]; then
    echo "WARNING: No messages found in topic" >&2
    echo ""
    echo "Possible reasons:" >&2
    echo "  1. CDC connector not started yet" >&2
    echo "  2. No changes have been made to the table" >&2
    echo "  3. Topic does not exist yet" >&2
    echo ""
elif [ $EXIT_CODE -ne 0 ]; then
    echo "ERROR: Failed to read from Kafka" >&2
    echo "Error details: $OUTPUT" >&2
    exit 1
else
    echo "Messages received:"
    echo ""
    echo "$OUTPUT" | while IFS= read -r line; do
        if [ -z "$line" ]; then
            continue
        fi
        
        # Check if line is valid JSON
        if echo "$line" | grep -q '^\{'; then
            echo "--- Message ---"
            
            # Try to pretty-print JSON if jq is available
            if command -v jq &> /dev/null; then
                echo "$line" | jq '.' 2>/dev/null || echo "$line"
            else
                echo "$line"
            fi
            echo ""
        fi
    done
fi

echo "=========================================="
echo "Payload verification completed"
echo "=========================================="
