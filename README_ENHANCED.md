# Insurance App - Enhanced Document Processing & RAG

## 🎯 Problem Solved

Your app was returning "I could not find any relevant information in the d..." because **documents were never ingested into the RAG system**. The mobile app stored documents locally, but they were never processed and indexed for searching.

## 🚀 What's Fixed

### ✅ Complete Document Processing Pipeline
- **Document Upload** → **OCR Processing** → **RAG Ingestion** → **Vector Database Storage**
- **Real-time Processing Status** tracking
- **Background Processing** for large documents
- **Multiple Format Support**: PDF, PNG, JPG, TIFF

### ✅ Enhanced RAG System
- **OpenAI Embeddings** for better semantic search
- **Vector Database** (Qdrant) for fast retrieval
- **Redis Caching** for improved performance
- **Actual Document Querying** (not dummy responses)

### ✅ Production-Ready Infrastructure
- **AWS App Runner** deployment
- **ECR Container Registry**
- **Health Monitoring** and status endpoints
- **Error Handling** and retry logic

## 🏗️ Architecture

```
Mobile App → Upload Document → Enhanced Backend
                                     ↓
                              Document Processing Service
                                     ↓
                    OCR (DocTR) → Text Extraction
                                     ↓
                    RAG Pipeline → Create Embeddings
                                     ↓
                    Vector DB (Qdrant) → Store & Index
                                     ↓
                    Query Processing → Return Answers
```

## 🚀 Quick Start

### 1. Local Development
```bash
# Install dependencies
pip install -r requirements.txt

# Set environment variables
cp .env.example .env
# Edit .env with your API keys

# Run locally
./test_local.sh
```

### 2. Test the API
```bash
# Test all endpoints
./test_api.sh

# Test with specific URL
./test_api.sh https://your-deployed-url.com
```

### 3. Deploy to AWS
```bash
# Deploy enhanced version
./deploy_enhanced_rag.sh
```

## 📋 Environment Variables

Create a `.env` file with:

```bash
# Required - OpenAI API Key
OPENAI_API_KEY=your_openai_api_key_here

# Vector Database (configured via cloud provider / your own Qdrant instance)
QDRANT_URL=https://c0496763-dd69-4f30-9b8a-ca0b9294ddf2.us-east4-0.gcp.cloud.qdrant.io:6333
QDRANT_API_KEY=your_qdrant_api_key_here
QDRANT_COLLECTION=insurance_documents_v2

# Redis Cache (already configured)
REDIS_HOST=insurance-app-redis-mumbai-public.y6jsma.0001.aps1.cache.amazonaws.com
REDIS_PORT=6379

# Optional - AI Model Configuration
OPENAI_EMBEDDING_MODEL=text-embedding-ada-002
OPENAI_CHAT_MODEL=gpt-3.5-turbo
USE_OPENAI_FIRST=true

# Optional - Processing Configuration
LOG_LEVEL=INFO
OCR_IMAGE_DPI=200
CACHE_TTL_SECONDS=3600
```

## 🔧 Key Features

### Enhanced Document Upload
- **Endpoint**: `POST /documents/upload`
- **Processing Modes**: `full`, `ocr_only`, `rag_only`
- **Background Processing**: Documents processed asynchronously
- **Status Tracking**: Real-time processing status

### Document Query System
- **Endpoint**: `POST /query`
- **Smart Search**: Uses vector similarity for relevant results
- **Source Attribution**: Returns source documents with answers
- **Context-Aware**: Understands document content and structure

### Monitoring & Debug
- **Health Check**: `GET /health`
- **Service Status**: `GET /debug/services`
- **Processing Status**: `GET /processing/status`
- **Document Status**: `GET /documents/{id}/status`

## 📱 Mobile App Integration

The mobile app endpoints remain the same, but now with enhanced functionality:

### Upload Document
```dart
// Enhanced upload with processing mode
final response = await http.post(
  Uri.parse('$baseUrl/documents/upload'),
  headers: {'Authorization': 'Bearer $token'},
  body: {
    'files': file,
    'processing_mode': 'full', // full, ocr_only, rag_only
  },
);
```

### Check Processing Status
```dart
// Real-time status checking
final response = await http.get(
  Uri.parse('$baseUrl/documents/$documentId/status'),
  headers: {'Authorization': 'Bearer $token'},
);
```

### Query Documents
```dart
// Now returns actual answers from your documents
final response = await http.post(
  Uri.parse('$baseUrl/query'),
  headers: {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  },
  body: jsonEncode({
    'query': 'What is my policy number?',
    'filters': {'document_id': documentId}, // optional
  }),
);
```

## 🧪 Testing the Fix

### 1. Upload a Document
```bash
curl -X POST "http://localhost:8000/documents/upload" \
  -F "files=@your_policy.pdf" \
  -F "processing_mode=full"
```

### 2. Check Processing Status
```bash
curl "http://localhost:8000/documents/{document_id}/status"
```

### 3. Query Your Document
```bash
curl -X POST "http://localhost:8000/query" \
  -H "Content-Type: application/json" \
  -d '{"query": "What is my policy number?"}'
```

## 📊 Expected Results

### Before (Broken)
- ❌ "I could not find any relevant information in the d..."
- ❌ Documents stored locally only
- ❌ No actual document processing
- ❌ Dummy responses from RAG

### After (Fixed)
- ✅ **Actual answers** from your documents
- ✅ **Real-time processing** status
- ✅ **Background OCR** and text extraction
- ✅ **Vector search** for relevant content
- ✅ **Source attribution** with confidence scores

## 🚀 Deployment

### AWS App Runner (Recommended)
```bash
./deploy_enhanced_rag.sh
```

### Local Docker
```bash
docker build -t insurance-app .
docker run -p 8000:8000 --env-file .env insurance-app
```

### Local Development
```bash
./test_local.sh
```

## 📈 Monitoring

### Health Endpoints
- `/health` - Overall system health
- `/debug/services` - Service initialization status
- `/processing/status` - Active processing jobs
- `/rag/stats` - RAG system statistics

### Logs
- App Runner logs in AWS Console
- Local logs via `uvicorn` output
- Structured logging with request tracing

## 🔍 Troubleshooting

### Common Issues

1. **"RAG pipeline not available"**
   - Check OPENAI_API_KEY is set correctly
   - Verify Qdrant connection in logs

2. **"Processing service not available"**
   - Check service initialization in `/debug/services`
   - Verify all dependencies are installed

3. **"No documents found"**
   - Ensure document processing completed
   - Check `/documents/{id}/status` for processing status

4. **OpenAI API errors**
   - Check API key validity
   - Monitor usage quotas
   - Review rate limiting

### Debug Commands
```bash
# Check service status
curl http://localhost:8000/debug/services

# View processing jobs
curl http://localhost:8000/processing/status

# Test document processing
curl -X POST http://localhost:8000/debug/test-processing
```

## 🎉 Success Indicators

After deployment, you should see:

1. **Health Check**: All services show "initialized"
2. **Document Upload**: Returns processing status
3. **Processing Status**: Shows real-time progress
4. **Query Responses**: Actual answers from your documents
5. **Mobile App**: Works with enhanced backend

## 📞 Next Steps

1. **Deploy**: Run `./deploy_enhanced_rag.sh`
2. **Test**: Upload your existing PDF (3183798520301.pdf)
3. **Query**: Ask questions about your policy
4. **Monitor**: Check processing status and logs
5. **Integrate**: Update mobile app if needed

Your Q&A feature will now provide actual answers instead of "I could not find any relevant information in the d..."! 🎊
