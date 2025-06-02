# 📱 Play Store Deployment Plan & Testing Strategy

This document outlines when and how to deploy the Flutter app to Google Play Store after Azure backend deployment.

---

## 📅 **Deployment Timeline**

### **Phase 1: Azure Backend (IN PROGRESS)**
- ✅ Deploy backend services to Azure
- ✅ Configure API keys
- ✅ Test backend endpoints

### **Phase 2: Flutter App Integration (NEXT)**
- 🔄 Update Flutter app to use Azure backend
- 🔄 Local testing with Azure backend
- 🔄 End-to-end functionality testing

### **Phase 3: Play Store Deployment (AFTER PHASE 2)**
- 🔄 Build production app bundle
- 🔄 Deploy to Play Store internal testing
- 🔄 Device testing via Play Store
- 🔄 Production deployment

---

## 🚀 **When to Deploy to Play Store**

**✅ Prerequisites (ALL must be completed):**

1. **Backend Fully Functional**
   - All three Azure services responding to health checks
   - API keys configured and working
   - Service-to-service communication verified

2. **Flutter App Updated & Tested**
   - `mobile/lib/services/api_service.dart` updated with Azure URLs
   - Local development testing completed
   - Document upload/processing working end-to-end
   - Error handling tested

3. **Production Readiness**
   - CORS configured properly for production
   - API rate limiting tested
   - Security review completed
   - Performance testing done

**🚫 Do NOT deploy to Play Store until:**
- Backend is stable and tested
- Mobile app works reliably with Azure backend
- All critical user flows are tested

---

## 🧪 **Testing Strategy (Pre-Play Store)**

### **Step 1: Local Development Testing**
```bash
# 1. Update Flutter app configuration
# Edit mobile/lib/services/api_service.dart:
static const String baseUrl = 'https://insurance-frontend-app.azurewebsites.net';

# 2. Run Flutter app locally
cd mobile
flutter run

# 3. Test core functionality:
# - Document upload
# - OCR processing
# - Query responses
# - Error handling
```

### **Step 2: Build Test (Before Play Store)**
```bash
# Test production build locally
cd mobile
flutter build apk --release
flutter install # Install on connected device

# OR build app bundle (Play Store format)
flutter build appbundle --release
```

### **Step 3: Backend Load Testing**
```bash
# Test Azure backend can handle multiple requests
# Test document processing with real files
curl -X POST https://insurance-frontend-app.azurewebsites.net/query \
  -H "Content-Type: application/json" \
  -d '{"query": "What is my coverage limit?"}'
```

---

## 📦 **Play Store Deployment Process**

### **Option A: Internal Testing First (RECOMMENDED)**

1. **Build App Bundle**
   ```bash
   cd mobile
   flutter build appbundle --release
   # Output: build/app/outputs/bundle/release/app-release.aab
   ```

2. **Upload to Play Console**
   - Go to [Google Play Console](https://play.google.com/console)
   - Select your app (or create new app)
   - Go to "Testing" → "Internal testing"
   - Upload `app-release.aab`
   - Add internal testers (your email addresses)

3. **Internal Testing**
   - Install via Play Store link sent to testers
   - Test all functionality on real devices
   - Verify Azure backend integration
   - Test different device types/Android versions

4. **Production Release**
   - Once internal testing passes
   - Promote to "Production" track
   - Complete Play Store review process

### **Option B: Direct Production (Higher Risk)**
- Skip internal testing
- Deploy directly to production
- **NOT RECOMMENDED** until thoroughly tested

---

## 🧪 **Play Store Testing Checklist**

### **Pre-Upload Testing**
- [ ] Flutter app builds successfully (`flutter build appbundle`)
- [ ] App connects to Azure backend correctly
- [ ] Document upload works
- [ ] OCR processing returns results
- [ ] Query functionality works
- [ ] Error handling is graceful
- [ ] App permissions are correct
- [ ] App icon and metadata are ready

### **Internal Testing Phase**
- [ ] Install via Play Store works
- [ ] App launches successfully
- [ ] Backend connectivity from Play Store version
- [ ] All core features work on test devices
- [ ] Performance is acceptable
- [ ] No crashes or major bugs

### **Production Readiness**
- [ ] Internal testing completed successfully
- [ ] Privacy policy uploaded
- [ ] App store listing complete
- [ ] Content rating completed
- [ ] Target audience set
- [ ] Pricing and distribution configured

---

## 🔗 **Updated Flutter App Configuration**

### **Current (Local Development)**
```dart
// mobile/lib/services/api_service.dart
static const String baseUrl = 'http://172.21.0.237:8080';
```

### **Production (Azure Backend)**
```dart
// mobile/lib/services/api_service.dart  
static const String baseUrl = 'https://insurance-frontend-app.azurewebsites.net';
```

### **Environment-Based Configuration (Advanced)**
```dart
// Consider environment-based config for staging vs production
class ApiConfig {
  static const String _baseUrlProd = 'https://insurance-frontend-app.azurewebsites.net';
  static const String _baseUrlStaging = 'https://insurance-frontend-staging.azurewebsites.net';
  
  static String get baseUrl {
    return const bool.fromEnvironment('dart.vm.product') ? _baseUrlProd : _baseUrlStaging;
  }
}
```

---

## ⚠️ **Important Considerations**

### **Play Store Review Time**
- **First submission**: 7+ days review time
- **Updates**: 2-3 days typically
- **Plan accordingly** for your launch timeline

### **Backend Stability**
- Ensure Azure backend is stable for **at least 24-48 hours** before Play Store submission
- Monitor Azure service logs during initial Play Store testing

### **Rollback Plan**
- Keep previous working version ready
- Have rollback procedure documented
- Monitor app crashes/errors after Play Store deployment

---

## 📊 **Success Metrics**

### **Technical Metrics**
- App crash rate < 1%
- API response time < 2 seconds
- Document processing success rate > 95%
- App store rating > 4.0

### **User Experience Metrics**
- Successful document uploads
- Query response accuracy
- User retention after first use

---

## 🗓️ **Estimated Timeline**

| Phase | Duration | Dependencies |
|-------|----------|--------------|
| **Azure Backend Testing** | 1-2 days | Deployment script completion |
| **Flutter App Update & Testing** | 2-3 days | Backend stability |
| **Internal Play Store Testing** | 3-5 days | App bundle creation |
| **Production Play Store Release** | 7-10 days | Google review process |
| **Total** | **13-20 days** | From backend deployment |

---

## 📝 **Next Immediate Steps**

**Right Now:**
1. ⏳ Wait for Azure deployment to complete
2. ⏳ Run `./scripts/set_api_keys.sh`
3. ⏳ Test Azure backend endpoints

**After Backend is Ready:**
1. Update Flutter app configuration
2. Test locally with Azure backend
3. Build and test app bundle locally
4. Internal Play Store testing
5. Production deployment

---

**🎯 Key Point**: Play Store deployment should happen **AFTER** complete Azure backend testing and local Flutter app testing. Don't rush to Play Store until everything works reliably! 