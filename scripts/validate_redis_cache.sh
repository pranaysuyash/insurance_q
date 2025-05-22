#!/bin/bash

# Redis Cache Validator Runner
# This script runs the Redis cache validation utility within the Docker environment

# Display help message
show_help() {
    echo "Redis Cache Validator Runner"
    echo "----------------------------"
    echo "This script runs the Redis cache validator utility to check and fix"
    echo "response format issues in the Redis cache used by the RAG system."
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --dry-run       Check for issues without making changes"
    echo "  --verbose       Show detailed information about each key"
    echo "  --pattern=GLOB  Redis key pattern to scan (default: rag:query:*)"
    echo "  --help          Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                          # Run validation and fix issues"
    echo "  $0 --dry-run                # Only report issues"
    echo "  $0 --verbose --pattern='*'  # Check all cache keys with details"
}

# Default values
DRY_RUN=""
VERBOSE=""
PATTERN="rag:query:*"

# Parse arguments
for arg in "$@"; do
    case $arg in
        --help)
            show_help
            exit 0
            ;;
        --dry-run)
            DRY_RUN="--dry-run"
            shift
            ;;
        --verbose)
            VERBOSE="--verbose"
            shift
            ;;
        --pattern=*)
            PATTERN="${arg#*=}"
            shift
            ;;
        *)
            echo "Unknown option: $arg"
            show_help
            exit 1
            ;;
    esac
done

# Build the command
VALIDATOR_CMD="python3 /app/utils/validate_redis_cache.py $DRY_RUN $VERBOSE --pattern='$PATTERN'"

echo "Running Redis cache validator..."
echo "Command: $VALIDATOR_CMD"

# Run the command inside the rag_service container
docker-compose exec rag_service sh -c "$VALIDATOR_CMD"

# Store exit status
exit_status=$?

# Exit with the same status
if [ $exit_status -ne 0 ]; then
    echo "Validation script failed with status $exit_status"
    exit $exit_status
fi 