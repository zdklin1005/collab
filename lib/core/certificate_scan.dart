import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import 'localquest_theme.dart';
import 'localquest_widgets.dart';
import 'ssm_verification.dart';

/// Legacy candidate extraction for backward compatibility
String? registrationCandidate(String text) {
  final analysis = SsmVerificationEngine.analyze(text: text);
  return analysis.formattedRegistrationNumber ??
      analysis.modernRegistrationNumber ??
      analysis.legacyRegistrationNumber;
}

class CertificateScanButton extends StatefulWidget {
  const CertificateScanButton({
    super.key,
    required this.onRegistration,
    this.businessName,
    this.onVerificationResult,
  });

  final ValueChanged<String> onRegistration;
  final String? businessName;
  final ValueChanged<SsmAnalysisResult>? onVerificationResult;

  @override
  State<CertificateScanButton> createState() => _CertificateScanButtonState();
}

class _CertificateScanButtonState extends State<CertificateScanButton> {
  bool busy = false;

  Future<void> scan() async {
    if (busy) return;

    final source = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        decoration: const BoxDecoration(
          color: LqColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Select SSM Certificate Source',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Capture a photo or upload a saved image of your Malaysian SSM Borang D registration certificate.',
              style: TextStyle(color: LqColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: LqColors.primarySoft,
                foregroundColor: LqColors.primary,
                child: Icon(Icons.photo_camera_outlined),
              ),
              title: const Text(
                'Take photo with camera',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text(
                'Capture your SSM certificate directly with camera',
                style: TextStyle(fontSize: 11, color: LqColors.muted),
              ),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: LqColors.primarySoft,
                foregroundColor: LqColors.primary,
                child: Icon(Icons.photo_library_outlined),
              ),
              title: const Text(
                'Upload photo from gallery',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text(
                'Select any saved or scanned SSM image from photos',
                style: TextStyle(fontSize: 11, color: LqColors.muted),
              ),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
          ],
        ),
      ),
    );

    if (source == 'camera') {
      await _scanFromSource(ImageSource.camera);
    } else if (source == 'gallery') {
      await _scanFromSource(ImageSource.gallery);
    }
  }

  Future<void> _scanFromSource(ImageSource imageSource) async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      showLqMessage(
        context,
        'Device photo scanning is available on Android and iOS devices.',
        error: true,
      );
      return;
    }
    setState(() => busy = true);
    final recognizer = TextRecognizer();
    try {
      final photo = await ImagePicker().pickImage(
        source: imageSource,
        maxWidth: 2400,
      );
      if (photo == null) return;
      final result = await recognizer.processImage(
        InputImage.fromFilePath(photo.path),
      );
      if (!mounted) return;
      await _processTextAndReview(result.text);
    } catch (_) {
      if (mounted) {
        showLqMessage(
          context,
          'Could not read this certificate. Choose a clear photo or enter details manually.',
          error: true,
        );
      }
    } finally {
      await recognizer.close();
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _processTextAndReview(String text) async {
    final analysis = SsmVerificationEngine.analyze(
      text: text,
      userEnteredBusinessName: widget.businessName,
    );
    final candidate = analysis.formattedRegistrationNumber ??
        analysis.modernRegistrationNumber ??
        analysis.legacyRegistrationNumber;

    if (!mounted) return;

    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'SSM Certificate Analysis',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (analysis.isVerified)
                      const SsmVerifiedBadge(compact: true),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: analysis.isVerified
                        ? LqColors.greenSoft
                        : (analysis.isExpired
                              ? const Color(0xFFFEE2E2)
                              : const Color(0xFFF1F5F9)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    analysis.statusExplanation,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                      color: analysis.isVerified
                          ? const Color(0xFF2C5E26)
                          : (analysis.isExpired
                                ? const Color(0xFF991B1B)
                                : LqColors.primaryDark),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                if (candidate != null) ...[
                  const Text(
                    'Detected SSM Number:',
                    style: TextStyle(fontSize: 12, color: LqColors.muted),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    candidate,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ] else ...[
                  const Text(
                    'No registration number detected. Enter manually.',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: LqColors.muted,
                    ),
                  ),
                ],
                if (analysis.expiryDate != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        analysis.isExpired
                            ? Icons.warning_amber_rounded
                            : Icons.check_circle_outline,
                        size: 14,
                        color: analysis.isExpired
                            ? Colors.red
                            : const Color(0xFF42723B),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        analysis.isExpired
                            ? 'Expired on ${_formatDate(analysis.expiryDate)}'
                            : 'Valid until ${_formatDate(analysis.expiryDate)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: analysis.isExpired
                              ? Colors.red
                              : const Color(0xFF42723B),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                const Text(
                  'Extracted Document Text:',
                  style: TextStyle(
                    fontSize: 11,
                    color: LqColors.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 110,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      text.isEmpty
                          ? 'No readable text found. Please upload a clear photo.'
                          : text,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (candidate != null)
                  LqButton(
                    label: analysis.isVerified
                        ? 'Apply verified SSM number'
                        : 'Use this number',
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
      widget.onVerificationResult?.call(analysis);
    }
  }

  static String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
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
      busy ? 'Analyzing certificate…' : 'Scan registration certificate',
    ),
  );
}
