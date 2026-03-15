#!/bin/bash

# Codemagic Service Account Encoder
# This script helps encode your Google Play service account JSON to base64

echo "=========================================="
echo "Codemagic Service Account JSON Encoder"
echo "=========================================="
echo ""

# Check if file path is provided
if [ -z "$1" ]; then
    echo "Usage: ./encode_service_account.sh <path-to-service-account.json>"
    echo ""
    echo "Example:"
    echo "  ./encode_service_account.sh ~/Downloads/play-store-service-account.json"
    echo ""
    exit 1
fi

SERVICE_ACCOUNT_FILE="$1"

# Check if file exists
if [ ! -f "$SERVICE_ACCOUNT_FILE" ]; then
    echo "❌ Error: File not found: $SERVICE_ACCOUNT_FILE"
    exit 1
fi

# Check if it's a valid JSON file
if ! jq empty "$SERVICE_ACCOUNT_FILE" 2>/dev/null; then
    echo "⚠️  Warning: File might not be valid JSON. Proceeding anyway..."
fi

echo "📄 Input file: $SERVICE_ACCOUNT_FILE"
echo ""
echo "🔄 Encoding to base64..."
echo ""

# Encode to base64
BASE64_OUTPUT=$(base64 -i "$SERVICE_ACCOUNT_FILE")

# Save to file
OUTPUT_FILE="service-account-base64.txt"
echo "$BASE64_OUTPUT" > "$OUTPUT_FILE"

echo "✅ Success! Base64 encoded content saved to: $OUTPUT_FILE"
echo ""
echo "=========================================="
echo "Next Steps:"
echo "=========================================="
echo ""
echo "1. Copy the content from: $OUTPUT_FILE"
echo ""
echo "2. Go to Codemagic Dashboard:"
echo "   → Your App → Environment variables"
echo ""
echo "3. Add new variable:"
echo "   Name: GCLOUD_SERVICE_ACCOUNT_CREDENTIALS"
echo "   Value: <paste the base64 content>"
echo "   Group: google_play"
echo "   Secure: ✅ Yes"
echo ""
echo "4. Save and you're done!"
echo ""
echo "=========================================="
echo ""

# Option to display the content
read -p "Do you want to display the base64 content now? (y/n): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "=========================================="
    echo "Base64 Content (copy this):"
    echo "=========================================="
    echo "$BASE64_OUTPUT"
    echo "=========================================="
fi

echo ""
echo "✨ Done!"
