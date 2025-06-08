#!/bin/bash

echo "🔍 Monitoring Azure App Services..."

SERVICES=("insurance-rag-app" "insurance-ocr-app" "insurance-frontend-app")

for i in {1..10}; do
    echo ""
    echo "=== Check #$i ==="
    
    for SERVICE in "${SERVICES[@]}"; do
        URL="https://$SERVICE.azurewebsites.net/health"
        echo -n "$SERVICE: "
        
        if curl -f -s -m 15 "$URL" > /dev/null; then
            echo "✅ HEALTHY"
        else
            echo "❌ NOT RESPONDING"
        fi
    done
    
    if [ $i -lt 10 ]; then
        echo "Waiting 30 seconds before next check..."
        sleep 30
    fi
done

echo ""
echo "🏁 Final test with response details:"
for SERVICE in "${SERVICES[@]}"; do
    echo ""
    echo "=== $SERVICE ==="
    curl -s "https://$SERVICE.azurewebsites.net/health" | head -5 || echo "No response"
done
