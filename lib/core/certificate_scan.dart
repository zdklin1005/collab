import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import 'localquest_widgets.dart';

/// OCR extracts candidates only; it never establishes registration authenticity.
String? registrationCandidate(String text) {
  final modern = RegExp(r'\b\d{12}\b').firstMatch(text);
  if (modern != null) return modern.group(0);
  return RegExp(
    r'\b(?:[A-Z]{1,3}\d{6,10}|\d{5,10})-[A-Z0-9]\b',
  ).firstMatch(text.toUpperCase())?.group(0);
}

class CertificateScanButton extends StatefulWidget {
  const CertificateScanButton({super.key, required this.onRegistration});
  final ValueChanged<String> onRegistration;
  @override
  State<CertificateScanButton> createState() => _CertificateScanButtonState();
}

class _CertificateScanButtonState extends State<CertificateScanButton> {
  bool busy = false;
  Future<void> scan() async {
    if (busy) return;
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      showLqMessage(
        context,
        'Certificate scanning is available in the Android and iOS app. Enter details manually here.',
      );
      return;
    }
    setState(() => busy = true);
    final recognizer = TextRecognizer();
    try {
      final photo = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 2400,
      );
      if (photo == null) return;
      final result = await recognizer.processImage(
        InputImage.fromFilePath(photo.path),
      );
      if (!mounted) return;
      final candidate = registrationCandidate(result.text);
      final accepted = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => Dialog(
          backgroundColor: Colors.transparent,
          child: LqCard(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Review certificate scan',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Text is read on your device. The certificate image is not uploaded. This does not verify SSM registration or certificate authenticity.',
                  ),
                  const SizedBox(height: 16),
                  Text(
                    candidate == null
                        ? 'No registration number detected. Enter it manually.'
                        : 'Possible registration number: $candidate',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 180,
                    child: SingleChildScrollView(
                      child: SelectableText(
                        result.text.isEmpty
                            ? 'No readable text. Try a sharper, well-lit photo.'
                            : result.text,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (candidate != null)
                    LqButton(
                      label: 'Use this number',
                      onPressed: () => Navigator.pop(dialogContext, true),
                    ),
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      if (accepted == true && candidate != null && mounted) {
        widget.onRegistration(candidate);
      }
    } catch (_) {
      if (mounted) {
        showLqMessage(
          context,
          'Could not read this certificate. Choose a clear photo or enter the details manually.',
          error: true,
        );
      }
    } finally {
      await recognizer.close();
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: busy ? null : scan,
    icon: busy
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.document_scanner_outlined),
    label: Text(
      busy ? 'Reading certificate…' : 'Scan registration certificate',
    ),
  );
}
