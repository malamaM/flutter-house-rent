import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:house_rent/config/api_config.dart';
import 'package:house_rent/theme/app_colors.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      (await SharedPreferences.getInstance()).getString('access_token');

  Future<void> _load() async {
    final token = await _token();
    if (token == null) return;
    try {
      final response = await http.get(
          Uri.parse('${ApiConfig.apiBase}/verification-request'),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json'
          });
      if (response.statusCode == 200 && mounted) {
        setState(() => status =
            jsonDecode(response.body)['verification_status'] ?? 'unverified');
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
        final result = await FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf']);
        final path = result?.files.single.path;
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
      final response = await http.Response.fromStream(await request.send());
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (!mounted) return;
      if (response.statusCode == 201) {
        setState(() => status = 'pending');
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Submitted securely. Haven Zambia will review your request.')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(body['message'] ?? 'Could not submit request.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Could not submit. Check your connection and try again.')));
      }
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locked = status == 'pending' || status == 'verified';
    return Scaffold(
        appBar: AppBar(title: const Text('Lister verification')),
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
                                ? Theme.of(context).colorScheme.primaryContainer
                                : Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(20)),
                        child: Row(children: [
                          Icon(
                              status == 'verified'
                                  ? Icons.verified_rounded
                                  : status == 'pending'
                                      ? Icons.schedule_rounded
                                      : Icons.shield_outlined,
                              color: AppColors.primary),
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
                                        fontWeight: FontWeight.w800)),
                                const SizedBox(height: 4),
                                Text(
                                    status == 'verified'
                                        ? 'Your verified badge is visible on your listings.'
                                        : status == 'pending'
                                            ? 'Your evidence is securely awaiting an administrator review.'
                                            : 'Submit genuine identity evidence. Verification is never guaranteed and can be revoked.',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant))
                              ]))
                        ])),
                    if (!locked) ...[
                      const SizedBox(height: 24),
                      DropdownButtonFormField<String>(
                          value: type,
                          decoration:
                              const InputDecoration(labelText: 'Lister type'),
                          items: const [
                            DropdownMenuItem(
                                value: 'individual_lister',
                                child: Text('Individual lister')),
                            DropdownMenuItem(
                                value: 'agency',
                                child: Text('Registered agency')),
                            DropdownMenuItem(
                                value: 'property_manager',
                                child: Text('Property manager'))
                          ],
                          onChanged: (value) => setState(() => type = value!)),
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
                      DropdownButtonFormField<String>(
                          value: documentType,
                          decoration: const InputDecoration(
                              labelText: 'Identity document'),
                          items: const [
                            DropdownMenuItem(value: 'nrc', child: Text('NRC')),
                            DropdownMenuItem(
                                value: 'drivers_license',
                                child: Text("Driver's licence")),
                            DropdownMenuItem(
                                value: 'passport', child: Text('Passport'))
                          ],
                          onChanged: (value) =>
                              setState(() => documentType = value!)),
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

  @override
  void dispose() {
    phone.dispose();
    note.dispose();
    super.dispose();
  }
}
