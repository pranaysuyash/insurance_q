# 📱 Insurance RAG App - APK Distribution Guide

## 📱 Latest Release Build - FIXED VERSION

### **Version**: v20250611-1631 (June 11, 2025 - Fixed)
### **Recommended APK**: `insurance-app-arm64-v20250611-1631.apk`
### **Size**: 24MB (ARM64 optimized)
### **Status**: ✅ **FIXED - Resolves "invalid package" issues**

## 🎯 Quick Start for Team Members

### ✅ **Recommended APK for Most Devices**
**File**: `app-release.apk` (52.3MB)  
**Compatibility**: Works on all Android devices  
**Best for**: Team distribution and testing  

## 📦 Available APK Files

| APK File | Size | Best For | Architecture |
|----------|------|----------|--------------|
| **app-release.apk** | 52.3MB | **Team distribution** | Universal (all devices) |
| **app-arm64-v8a-release.apk** | 19.8MB | Modern phones (2018+) | ARM64-v8a |
| **app-armeabi-v7a-release.apk** | 17.0MB | Older phones (2015-2018) | ARMv7 |
| **app-x86_64-release.apk** | 21.0MB | Emulators/x86 devices | x86_64 |

## 🔧 Installation Instructions

### For Android Devices:

#### **Step 1: Enable Unknown Sources**
1. Go to **Settings > Security**
2. Enable **"Install unknown apps"** or **"Unknown sources"**
3. Allow installation from your file manager

#### **Step 2: Install APK**
1. Download the APK file to your phone
2. Open with a file manager
3. Tap the APK file and install
4. Grant necessary permissions

#### **Step 3: First Launch**
1. Open the **Insurance RAG** app
2. The app will connect to: `https://nrmmvtpyaf.ap-south-1.awsapprunner.com`
3. Test with a sample query like "What is a premium?"

## 📱 Device-Specific Recommendations

### **Realme Narzo N61 (Android 14)**
- **Primary**: `app-arm64-v8a-release.apk` (19.8MB)
- **Fallback**: `app-release.apk` (52.3MB)
- **Note**: Enable Developer Options if installation fails

### **Samsung Galaxy Devices**
- **Primary**: `app-release.apk` (52.3MB)
- **Alternative**: `app-arm64-v8a-release.apk` (19.8MB)

### **OnePlus/Oppo/Vivo Devices**
- **Primary**: `app-arm64-v8a-release.apk` (19.8MB)
- **Fallback**: `app-release.apk` (52.3MB)

### **Xiaomi/Redmi Devices**
- **Primary**: `app-release.apk` (52.3MB)
- **Note**: May need to disable MIUI Optimization

### **Android Emulators**
- **Use**: `app-x86_64-release.apk` (21.0MB)
- **Alternative**: `app-release.apk` (52.3MB)

## 🛠️ Troubleshooting

### **"Package appears to be invalid"**
1. **Clear any existing installation** of the app
2. **Try a different APK** from the list above
3. **Enable Developer Options**:
   - Settings > About Phone > Tap Build Number 7 times
   - Settings > Developer Options > Enable USB Debugging
4. **Use ADB installation** (if available):
   ```bash
   adb install app-release.apk
   ```

### **"App not installed"**
1. **Check available storage** (need ~100MB free)
2. **Restart your phone** and try again
3. **Try the universal APK**: `app-release.apk`

### **"Installation blocked"**
1. **Disable antivirus** temporarily
2. **Check manufacturer restrictions**:
   - Xiaomi: Disable MIUI Optimization
   - Realme: Disable Pure Mode
   - Samsung: Allow installation from unknown sources

### **App crashes on startup**
1. **Clear app data** if previously installed
2. **Check internet connection**
3. **Try a different APK variant**

## 🌐 App Features to Test

### **Core Functionality**
- [x] **Document Upload**: Upload insurance policy PDFs/images
- [x] **OCR Processing**: Text extraction from documents
- [x] **Q&A System**: Ask questions about uploaded policies
- [x] **Document Management**: View and organize documents

### **Test Queries**
Try these sample questions after uploading a document:
- "What is the policy number?"
- "What is the coverage amount?"
- "Who is the policy holder?"
- "What are the exclusions?"

### **Backend Connection**
- **Service URL**: https://nrmmvtpyaf.ap-south-1.awsapprunner.com
- **Health Check**: Should show all services operational
- **Response Time**: Queries should respond within 2-3 seconds

## 📊 System Requirements

### **Minimum Requirements**
- **Android**: 6.0 (API 23) or higher
- **RAM**: 2GB minimum, 4GB recommended
- **Storage**: 100MB free space
- **Internet**: Required for backend connectivity

### **Recommended Specifications**
- **Android**: 8.0+ for best performance
- **RAM**: 4GB+ for smooth operation
- **Processor**: ARM64-v8a (modern phones)
- **Network**: Wi-Fi or 4G for optimal experience

## 🔐 Security Notes

### **APK Signing**
- All APKs are signed with debug certificates
- Safe for internal testing and development
- **Not suitable for Play Store distribution**

### **Permissions Required**
- **Internet**: Backend API communication
- **Camera**: Document photo capture
- **Storage**: Document file access
- **Vibration**: User feedback

## 📞 Support & Feedback

### **For Technical Issues**
1. **Check this guide** for common solutions
2. **Try different APK variants** if one doesn't work
3. **Report issues** with device model and Android version

### **For App Feedback**
- **Feature requests**: Document any missing functionality
- **Performance issues**: Note response times and crashes
- **UI/UX feedback**: Suggest improvements

### **Backend Status**
- **Service URL**: https://nrmmvtpyaf.ap-south-1.awsapprunner.com/health
- **Status**: Should show "RAG: Available" and "Document Processing: Available"

## 🎯 Testing Checklist

### **Installation Testing**
- [ ] APK installs successfully
- [ ] App launches without crashes
- [ ] Permissions granted correctly

### **Functionality Testing**
- [ ] Document upload works
- [ ] OCR text extraction successful
- [ ] Q&A queries return relevant answers
- [ ] Document list displays correctly

### **Performance Testing**
- [ ] App responds within 3 seconds
- [ ] No memory leaks or crashes
- [ ] Smooth navigation between screens

### **Network Testing**
- [ ] Works on Wi-Fi
- [ ] Works on mobile data
- [ ] Handles network interruptions gracefully

---

## 📍 File Locations

**✅ WORKING APK (Use This One):**
```
mobile/build/app/outputs/apk/release/app-release.apk
```

**❌ Problematic APKs (Don't Use):**
```
mobile/build/app/outputs/flutter-apk/
```

**Note**: The `apk/release` directory contains properly built APKs, while `flutter-apk` may have signing issues.

**Happy Testing!** 🚀

For any issues or questions, refer to this guide or contact the development team. 

## 🔧 **Available APK Options**

### **Option 1: ARM64 APK (RECOMMENDED)**
- **File**: `insurance-app-arm64-v20250611-1631.apk`
- **Size**: 24MB
- **Compatibility**: Modern Android devices (ARM64)
- **Best For**: Most Android phones and tablets (2018+)

### **Option 2: Universal APK**
- **File**: `insurance-app-fixed-v20250611-1631.apk`
- **Size**: 55MB
- **Compatibility**: All Android devices
- **Best For**: Older devices or when ARM64 doesn't work

### **Option 3: App Bundle (Play Store)**
- **File**: `insurance-app-bundle-v20250611.aab`
- **Size**: 44MB
- **Use**: Google Play Store upload only

## ✅ **What Was Fixed**

### **"Invalid Package" Issue Resolution**
- **Problem**: Previous APK showed "invalid package" on some devices
- **Root Cause**: Improper signing configuration and namespace conflicts
- **Solution**: 
  - Fixed Android namespace: `com.coverwise.app`
  - Proper debug signing for testing compatibility
  - Disabled problematic minification
  - Created architecture-specific builds

### **Technical Improvements**
- ✅ Updated application ID to avoid conflicts
- ✅ Proper Gradle configuration with Kotlin DSL
- ✅ Optimized build settings for compatibility
- ✅ Split APKs for smaller download sizes
- ✅ Removed problematic ProGuard rules

## 🎯 **What's New in This Release**

### ✅ **Enhanced Document Type Detection**
- **Fixed**: Documents now properly show as "Health Insurance", "Auto Insurance", etc. instead of "Unknown"
- **Added**: Comprehensive Indian insurance company recognition (Niva Bupa, Star Health, ICICI Lombard, etc.)
- **New**: Travel Insurance support with dedicated icons and detection
- **Feature**: Manual refresh button to re-detect document types

### ✅ **Improved User Experience**
- Better document categorization in dashboard
- Accurate document type counts and icons
- Enhanced insurance company recognition
- User-friendly refresh functionality with progress indicators

### ✅ **Backend Integration**
- **Stable Backend**: `https://aa2485vt7t.ap-south-1.awsapprunner.com`
- **RAG System**: Fully operational with document-specific Q&A
- **Anti-Abuse**: Rate limiting and session management active
- **Lead Capture**: Optional email/phone collection for business leads

## 🚀 **Installation Instructions**

### **For Android Devices**:
1. **Download the APK**:
   - **Recommended**: `insurance-app-arm64-v20250611-1631.apk` (24MB)
   - **Fallback**: `insurance-app-fixed-v20250611-1631.apk` (55MB)

2. **Enable Unknown Sources**:
   - Go to Settings → Security → Unknown Sources
   - Enable "Allow installation of apps from unknown sources"

3. **Install the APK**:
   - Transfer the APK file to your Android device
   - Tap on the APK file to install
   - Follow the installation prompts

4. **Grant Permissions**:
   - Camera (for document scanning)
   - Storage (for document management)
   - Network (for backend communication)

## 📋 **Testing Checklist**

### **Installation Verification**
- [ ] **APK Installs Successfully**: No "invalid package" errors
- [ ] **App Launches**: Opens without crashes
- [ ] **Permissions Granted**: Camera, storage, network access
- [ ] **Backend Connection**: Can reach AWS backend

### **Core Functionality**
- [ ] **Document Upload**: Upload PDF/image insurance documents
- [ ] **Document Type Detection**: Verify documents show correct type (Health, Auto, Life, etc.)
- [ ] **Q&A System**: Ask questions about uploaded documents
- [ ] **Backend Connectivity**: Confirm connection to AWS backend
- [ ] **Offline Mode**: Test app functionality without internet

### **New Features to Test**
- [ ] **Document Type Refresh**: Use refresh button in Documents screen
- [ ] **Insurance Company Recognition**: Upload Niva Bupa, Star Health, or other Indian insurance documents
- [ ] **Travel Insurance**: Test with travel insurance documents
- [ ] **Dashboard Counts**: Verify document type counts are accurate
- [ ] **Document Icons**: Check that proper icons appear for each insurance type

### **User Experience**
- [ ] **Navigation**: Test all 5 tabs (Home, Documents, QA, Family, More)
- [ ] **Upload Flow**: Complete document upload with optional lead capture
- [ ] **Error Handling**: Test with poor network conditions
- [ ] **Rate Limiting**: Test upload limits and user feedback

## 🔧 **Technical Specifications**

### **App Details**
- **Platform**: Android (API level 23+)
- **Architecture**: ARM64 (recommended) or Universal
- **Build Type**: Release (optimized)
- **Application ID**: `com.coverwise.app`
- **Signing**: Debug (compatible with all devices)

### **Backend Configuration**
- **API Endpoint**: `https://aa2485vt7t.ap-south-1.awsapprunner.com`
- **Session Management**: UUID-based with 24h expiration
- **Rate Limits**: 5 uploads per session, 10 per IP per day
- **Supported Formats**: PDF, JPG, PNG

### **Features Included**
- ✅ Document upload and OCR processing
- ✅ RAG-based Q&A system
- ✅ Document type classification (5 categories)
- ✅ Insurance company recognition
- ✅ Session-based rate limiting
- ✅ Optional lead capture
- ✅ Offline storage and fallback
- ✅ Usage statistics and monitoring

## 🐛 **Known Issues & Limitations**

### **Current Limitations**
- **File Size**: Maximum 10MB per document
- **Rate Limits**: 5 uploads per session for abuse prevention
- **Network**: Requires internet for Q&A functionality
- **Languages**: English only for document processing

### **Workarounds**
- **Large Files**: Compress images before upload
- **Rate Limits**: Wait for session reset or use different device
- **Network Issues**: App works offline for document viewing
- **Document Types**: Use manual refresh if type not detected

## 📊 **Testing Scenarios**

### **Scenario 1: Health Insurance Document**
1. Upload a Niva Bupa or Star Health policy document
2. Verify it's detected as "Health Insurance"
3. Ask questions like "What is my coverage amount?"
4. Check that policy holder information is extracted

### **Scenario 2: Document Type Refresh**
1. Upload any insurance document
2. If type shows as "Unknown", tap refresh button in Documents screen
3. Verify document type updates correctly
4. Check dashboard counts are updated

### **Scenario 3: Lead Capture Flow**
1. Upload a document without providing email/phone
2. Complete the upload process
3. Optionally provide contact information when prompted
4. Verify document is saved and accessible

### **Scenario 4: Q&A Functionality**
1. Upload an insurance document
2. Navigate to Q&A tab
3. Select the document from dropdown
4. Ask both predefined and custom questions
5. Verify answers are relevant to the document

## 📞 **Support & Feedback**

### **For Installation Issues**:
- Try the ARM64 APK first: `insurance-app-arm64-v20250611-1631.apk`
- If that fails, use Universal APK: `insurance-app-fixed-v20250611-1631.apk`
- Ensure "Unknown Sources" is enabled
- Check available storage space (need ~100MB free)

### **For Testing Issues**:
- Check network connectivity
- Verify file format is supported (PDF, JPG, PNG)
- Try manual document type refresh
- Restart app if experiencing issues

### **For Feature Requests**:
- Document any missing insurance company recognition
- Report document types that aren't detected properly
- Suggest improvements to Q&A functionality
- Provide feedback on user experience

## 🎯 **Success Metrics**

### **Expected Performance**
- **Installation Success Rate**: >98% (fixed from previous issues)
- **Upload Success Rate**: >95%
- **Document Type Detection**: >90% accuracy
- **Q&A Response Time**: <5 seconds
- **App Startup Time**: <3 seconds

### **User Experience Goals**
- Intuitive document upload flow
- Clear document categorization
- Accurate answers to insurance questions
- Smooth navigation between features

---

**Build Date**: June 11, 2025  
**Backend Status**: ✅ Operational  
**Last Updated**: June 11, 2025  
**Status**: ✅ **FIXED - Ready for Distribution**

This release resolves the "invalid package" issues and represents a significant improvement in document type detection and user experience, making it ready for broader testing and potential distribution. 
