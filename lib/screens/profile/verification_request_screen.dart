import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:house_rent/config/api_config.dart';
import 'package:house_rent/services/api_error.dart';
import 'package:house_rent/services/media_upload_policy.dart';
import 'package:house_rent/services/session_token_store.dart';
import 'package:house_rent/widgets/haven_navigation_bar.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class VerificationRequestScreen extends StatefulWidget {
  const VerificationRequestScreen({super.key});

  @override
  State<VerificationRequestScreen> createState() =>
      _VerificationRequestScreenState();
}

class _VerificationRequestScreenState extends State<VerificationRequestScreen> {
  final phone = TextEditingController();
  final note = TextEditingController();
  String type = 'individual_lister';
  String documentType = 'nrc';
  String status = 'unverified';
  XFile? documentFront;
  XFile? documentBack;
  XFile? selfie;
  bool loading = true;
  bool submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<String?> _token() async =>
      SessionTokenStore.read();

  Future<void> _load() async {
    final token = await _token();
    if (token == null) return;
    try {
      final response = await http.get(
          Uri.parse('${ApiConfig.apiBase}/verification-request'),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json'
          }).timeout(const Duration(seconds: 12));
      if (response.statusCode == 200 && mounted) {
        setState(() => status =
            jsonDecode(response.body)['verification_status'] ?? 'unverified');
      } else if (response.statusCode != 200) {
        throw HavenApiException.fromResponse(response,
            operation: 'load your verification status');
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(ApiErrorResolver.message(error,
                fallback: 'Haven could not load your verification status.'))));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _chooseDocumentSide(bool front) async {
    final source = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(children: [
          ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose image'),
              onTap: () => Navigator.pop(context, 'gallery')),
          ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take photo'),
              onTap: () => Navigator.pop(context, 'camera')),
          ListTile(
              leading: const Icon(Icons.attach_file_rounded),
              title: const Text('Choose file'),
              subtitle: const Text('JPG, PNG, WebP or PDF'),
              onTap: () => Navigator.pop(context, 'file')),
        ]),
      ),
    );
    if (source == null) return;
    XFile? selected;
    if (source == 'file') {
      try {
        final file = await FilePicker.pickFile(
            type: FileType.custom,
            allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf']);
        final path = file?.path;
        if (path != null) selected = XFile(path);
      } on MissingPluginException {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'The file picker needs a full app restart. You can use Camera or Photo Library now.')));
        return;
      }
    } else {
      try {
        selected = await ImagePicker().pickImage(
            source:
                source == 'camera' ? ImageSource.camera : ImageSource.gallery,
            imageQuality: 88,
            maxWidth: 2200);
      } on PlatformException catch (error) {
        if (source == 'camera') await _showCameraUnavailable(error);
        return;
      }
    }
    if (!mounted || selected == null) return;
    try {
      await MediaUploadPolicy.validateFile(
        selected.path,
        maxBytes: MediaUploadPolicy.maxVerificationFileBytes,
        label: front ? 'Front document' : 'Back document',
      );
    } on MediaUploadException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
      return;
    }
    setState(() {
      if (front) {
        documentFront = selected;
      } else {
        documentBack = selected;
      }
    });
  }

  Future<void> _captureSelfie() async {
    XFile? captured;
    try {
      captured = await ImagePicker().pickImage(
          source: ImageSource.camera,
          preferredCameraDevice: CameraDevice.front,
          imageQuality: 88,
          maxWidth: 1800);
    } on PlatformException catch (error) {
      await _showCameraUnavailable(error, selfie: true);
      return;
    }
    if (!mounted || captured == null) return;
    try {
      await MediaUploadPolicy.validateFile(
        captured.path,
        maxBytes: MediaUploadPolicy.maxVerificationFileBytes,
        label: 'Selfie',
      );
    } on MediaUploadException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
      return;
    }
    setState(() => selfie = captured);
  }

  Future<void> _showCameraUnavailable(PlatformException error,
      {bool selfie = false}) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.camera_front_outlined),
        title: const Text('Camera unavailable'),
        content: Text(selfie
            ? 'The iOS Simulator has no camera. Complete the live selfie on a physical phone; gallery upload stays disabled to protect verification integrity.'
            : 'The simulator cannot take photos. Choose an image or file instead, or continue on a physical phone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Got it'))
        ],
      ),
    );
  }

  Future<String?> _chooseOption({
    required String title,
    required List<MapEntry<String, String>> options,
  }) {
    return showCupertinoModalPopup<String>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(title),
        actions: [
          for (final option in options)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(context, option.key),
              child: Text(option.value),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  Future<void> _chooseListerType() async {
    final value = await _chooseOption(
      title: 'Lister type',
      options: const [
        MapEntry('individual_lister', 'Individual lister'),
        MapEntry('agency', 'Registered agency'),
        MapEntry('property_manager', 'Property manager'),
      ],
    );
    if (value != null && mounted) setState(() => type = value);
  }

  Future<void> _chooseDocumentType() async {
    final value = await _chooseOption(
      title: 'Identity document',
      options: const [
        MapEntry('nrc', 'NRC'),
        MapEntry('drivers_license', "Driver's licence"),
        MapEntry('passport', 'Passport'),
      ],
    );
    if (value != null && mounted) setState(() => documentType = value);
  }

  Future<void> _submit() async {
    if (phone.text.trim().isEmpty ||
        documentFront == null ||
        documentBack == null ||
        selfie == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Add your phone number, both sides of your ID and a live selfie.')));
      return;
    }
    final token = await _token();
    if (token == null) return;
    setState(() => submitting = true);
    try {
      await Future.wait([
        MediaUploadPolicy.validateFile(documentFront!.path,
            maxBytes: MediaUploadPolicy.maxVerificationFileBytes,
            label: 'Front document'),
        MediaUploadPolicy.validateFile(documentBack!.path,
            maxBytes: MediaUploadPolicy.maxVerificationFileBytes,
            label: 'Back document'),
        MediaUploadPolicy.validateFile(selfie!.path,
            maxBytes: MediaUploadPolicy.maxVerificationFileBytes,
            label: 'Selfie'),
      ]);
      final request = http.MultipartRequest(
          'POST', Uri.parse('${ApiConfig.apiBase}/verification-request'))
        ..headers.addAll(
            {'Authorization': 'Bearer $token', 'Accept': 'application/json'})
        ..fields.addAll({
          'type': type,
          'phone_number': phone.text.trim(),
          'document_type': documentType,
          'note': note.text.trim()
        });
      request.files.add(await http.MultipartFile.fromPath(
          'document_front', documentFront!.path));
      request.files.add(await http.MultipartFile.fromPath(
          'document_back', documentBack!.path));
      request.files
          .add(await http.MultipartFile.fromPath('selfie', selfie!.path));
      final response = await http.Response.fromStream(
        await request.send().timeout(const Duration(minutes: 5)),
      );
      if (!mounted) return;
      if (response.statusCode == 201) {
        setState(() => status = 'pending');
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Submitted securely. Haven Zambia will review your request.')));
      } else {
        throw HavenApiException.fromResponse(response,
            operation: 'submit your verification request');
      }
    } on HavenApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } on MediaUploadException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(ApiErrorResolver.message(error,
                fallback:
                    'Haven could not submit your verification request.'))));
      }
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locked = status == 'pending' || status == 'verified';
    final colors = Theme.of(context).colorScheme;
    final verifiedBackground = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF164B3B)
        : const Color(0xFFE0F4EA);
    final verifiedForeground = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFA7E6C7)
        : const Color(0xFF0A5F42);
    return Scaffold(
        appBar: const HavenNavigationBar(title: 'Lister verification'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
                children: [
                    Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                            color: status == 'verified'
                                ? verifiedBackground
                                : colors.surface,
                            borderRadius: BorderRadius.circular(20)),
                        child: Row(children: [
                          Icon(
                              status == 'verified'
                                  ? Icons.verified_rounded
                                  : status == 'pending'
                                      ? Icons.schedule_rounded
                                      : Icons.shield_outlined,
                              color: status == 'verified'
                                  ? verifiedForeground
                                  : colors.primary),
                          const SizedBox(width: 13),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(
                                  status == 'verified'
                                      ? 'Identity verified'
                                      : status == 'pending'
                                          ? 'Review in progress'
                                          : 'Earn renter confidence',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                    status == 'verified'
                                        ? 'Your verified badge is visible on your listings.'
                                        : status == 'pending'
                                            ? 'Your evidence is securely awaiting an administrator review.'
                                            : 'Submit genuine identity evidence. Verification is never guaranteed and can be revoked.',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: status == 'verified'
                                            ? verifiedForeground.withValues(
                                                alpha: .9)
                                            : colors.onSurfaceVariant))
                              ]))
                        ])),
                    if (!locked) ...[
                      const SizedBox(height: 24),
                      _VerificationSelectField(
                        label: 'Lister type',
                        value: _listerTypeLabel(type),
                        onTap: _chooseListerType,
                      ),
                      const SizedBox(height: 14),
                      TextField(
                          controller: phone,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                              labelText: 'Reachable phone number',
                              hintText: '+260...')),
                      const SizedBox(height: 14),
                      TextField(
                          controller: note,
                          maxLines: 4,
                          decoration: const InputDecoration(
                              labelText: 'About your rental activity',
                              hintText:
                                  'Tell us how you manage or own the properties you list.')),
                      const SizedBox(height: 18),
                      _VerificationSelectField(
                        label: 'Identity document',
                        value: _documentTypeLabel(documentType),
                        onTap: _chooseDocumentType,
                      ),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                          onPressed: () => _chooseDocumentSide(true),
                          icon: const Icon(Icons.badge_outlined),
                          label: Text(documentFront == null
                              ? 'Add document front'
                              : 'Document front selected')),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                          onPressed: () => _chooseDocumentSide(false),
                          icon: const Icon(Icons.badge_outlined),
                          label: Text(documentBack == null
                              ? 'Add document back'
                              : 'Document back selected')),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                          onPressed: _captureSelfie,
                          icon: const Icon(Icons.camera_front_outlined),
                          label: Text(selfie == null
                              ? 'Take live selfie'
                              : 'Live selfie captured')),
                      Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                              'Add clear front and back evidence using the camera, photo library or file picker. Your live selfie remains front-camera only. Evidence is private.',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant))),
                      const SizedBox(height: 22),
                      ElevatedButton.icon(
                          onPressed: submitting ? null : _submit,
                          icon: submitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.verified_user_outlined),
                          label: const Text('Request verification'))
                    ]
                  ]));
  }

  String _listerTypeLabel(String value) => switch (value) {
        'agency' => 'Registered agency',
        'property_manager' => 'Property manager',
        _ => 'Individual lister',
      };

  String _documentTypeLabel(String value) => switch (value) {
        'drivers_license' => "Driver's licence",
        'passport' => 'Passport',
        _ => 'NRC',
      };

  @override
  void dispose() {
    phone.dispose();
    note.dispose();
    super.dispose();
  }
}

class _VerificationSelectField extends StatelessWidget {
  const _VerificationSelectField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: '$label: $value',
      child: CupertinoButton(
        onPressed: onTap,
        padding: EdgeInsets.zero,
        pressedOpacity: .72,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 10, 14, 11),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colors.outlineVariant, width: .8),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: .2,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(CupertinoIcons.chevron_down,
                  size: 16, color: colors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
