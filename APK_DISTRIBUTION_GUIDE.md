# 📱 Insurance RAG App - APK Distribution Guide

**Version**: 1.0.3 (Build 13)  
**Release Date**: June 11, 2025  
**Backend**: AWS App Runner (https://nrmmvtpyaf.ap-south-1.awsapprunner.com)  

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

All APK files are located in:
```
/Users/pranay/Projects/medpiper/insurance_app/mobile/build/app/outputs/flutter-apk/
```

**Happy Testing!** 🚀

For any issues or questions, refer to this guide or contact the development team. 