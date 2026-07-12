import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:pdfx/pdfx.dart';
import 'package:path_provider/path_provider.dart';

/// On-device OCR for scanned/image-only PDFs using Google ML Kit.
///
/// When a user uploads a PDF that has no embedded text (a scanned document),
/// this service renders each page to an image and runs ML Kit text recognition
/// on it. This is free, on-device, and works offline — no cloud API needed.
///
/// The extracted text is then sent to the backend for RAG ingestion, same as
/// a digital PDF.
class MlOcrService {
  static final _textRecognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  /// Extracts text from a PDF. Renders each page to an image and runs ML Kit
  /// OCR on it. For digital PDFs, the OCR will still extract the text (just
  /// slower than direct text extraction — but reliable and consistent).
  ///
  /// Returns the full text and whether OCR was used.
  static Future<({String text, bool usedOcr})> extractTextFromFile(
    String filePath,
  ) async {
    if (!filePath.toLowerCase().endsWith('.pdf')) {
      // For image files, run OCR directly
      final text = await _recognizeFile(filePath);
      return (text: text, usedOcr: true);
    }

    PdfDocument? doc;
    try {
      doc = await PdfDocument.openFile(filePath);
      final buffer = StringBuffer();
      final tempDir = await getTemporaryDirectory();

      for (var i = 1; i <= doc.pagesCount; i++) {
        final page = await doc.getPage(i);
        // Render page to image at 2x for better OCR accuracy
        final img = await page.render(
          width: page.width * 2,
          height: page.height * 2,
        );
        if (img != null) {
          // Save rendered image to temp file for ML Kit
          final imgFile = File('${tempDir.path}/pdf_page_$i.png');
          await imgFile.writeAsBytes(img.bytes);

          final text = await _recognizeFile(imgFile.path);
          if (text.isNotEmpty) {
            buffer.writeln(text);
          }

          // Clean up temp image
          await imgFile.delete();
        }
        await page.close();
      }

      final result = buffer.toString().trim();
      return (text: result, usedOcr: result.isNotEmpty);
    } catch (e) {
      debugPrint('PDF OCR extraction error: $e');
      return (text: '', usedOcr: false);
    } finally {
      await doc?.close();
    }
  }

  /// Runs ML Kit text recognition on a file (image path).
  static Future<String> _recognizeFile(String filePath) async {
    try {
      final inputImage = InputImage.fromFilePath(filePath);
      final result = await _textRecognizer.processImage(inputImage);
      return result.text;
    } catch (e) {
      debugPrint('ML Kit OCR error: $e');
      return '';
    }
  }

  static Future<void> dispose() async {
    await _textRecognizer.close();
  }
}
