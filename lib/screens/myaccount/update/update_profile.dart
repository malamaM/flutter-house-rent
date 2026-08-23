import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:house_rent/config/api_config.dart';
import 'package:house_rent/services/app_data_service.dart';
import 'package:house_rent/services/api_error.dart';
import 'package:house_rent/services/media_upload_policy.dart';
import 'package:house_rent/widgets/haven_navigation_bar.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  static const _fallbackImage =
      'https://i.postimg.cc/0jqKB6mS/Profile-Image.png';

  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _whatsApp = TextEditingController();

  String _profileImageUrl = _fallbackImage;
  bool _loading = true;
  bool _saving = false;
  bool _uploadingPhoto = false;
  bool _whatsAppEnabled = false;
  bool _whatsAppSameAsPhone = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile({bool forceRefresh = false}) async {
    final data = await SessionService.currentUser(forceRefresh: forceRefresh);
    if (!mounted) return;
    if (data != null) {
      final phone = data['phone_number']?.toString() ?? '';
      final whatsapp = data['whatsapp_number']?.toString() ?? '';
      _firstName.text = data['first_name']?.toString() ?? '';
      _lastName.text = data['last_name']?.toString() ?? '';
      _email.text = data['email']?.toString() ?? '';
      _phone.text = phone;
      _whatsAppEnabled = whatsapp.isNotEmpty;
      _whatsAppSameAsPhone = whatsapp.isEmpty || whatsapp == phone;
      _whatsApp.text = _whatsAppSameAsPhone ? '' : whatsapp;
      final picture = data['profile_picture']?.toString();
      _profileImageUrl = picture == null || picture.isEmpty
          ? _fallbackImage
          : ApiConfig.storageUrl(picture);
    }
    setState(() => _loading = false);
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'This field is required' : null;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      if (token == null) throw const _ProfileException('Please sign in again.');
      final whatsappNumber = !_whatsAppEnabled
          ? null
          : _whatsAppSameAsPhone
              ? _phone.text.trim()
              : _whatsApp.text.trim();
      final changes = <String, dynamic>{
        'first_name': _firstName.text.trim(),
        'last_name': _lastName.text.trim(),
        'email': _email.text.trim(),
        'phone_number': _phone.text.trim(),
        'whatsapp_number': whatsappNumber,
      };
      final response = await http
          .post(
            Uri.parse('${ApiConfig.apiBase}/update-profile'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(changes),
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        throw HavenApiException.fromResponse(response,
            operation: 'save your personal information');
      }
      await SessionService.updateCachedUser(changes);
      _notice('Personal information updated');
    } on HavenApiException catch (error) {
      _notice(error.message);
    } on _ProfileException catch (error) {
      _notice(error.message);
    } catch (error) {
      _notice(ApiErrorResolver.message(error,
          fallback: 'Haven could not save your personal information.'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickImage() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 1600,
    );
    if (image == null) return;
    await _uploadImage(File(image.path));
  }

  Future<void> _uploadImage(File image) async {
    if (_uploadingPhoto) return;
    setState(() => _uploadingPhoto = true);
    try {
      await MediaUploadPolicy.validateFile(image.path,
          maxBytes: MediaUploadPolicy.maxImageBytes, label: 'Profile photo');
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      if (token == null) throw const _ProfileException('Please sign in again.');
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.apiBase}/update-profile-picture'),
      )
        ..headers['Authorization'] = 'Bearer $token'
        ..files.add(
            await http.MultipartFile.fromPath('profile_picture', image.path));
      final response = await http.Response.fromStream(
          await request.send().timeout(const Duration(minutes: 2)));
      if (response.statusCode != 200) {
        throw HavenApiException.fromResponse(response,
            operation: 'update your profile photo');
      }
      await _loadProfile(forceRefresh: true);
      _notice('Profile photo updated');
    } on HavenApiException catch (error) {
      _notice(error.message);
    } on MediaUploadException catch (error) {
      _notice(error.message);
    } on _ProfileException catch (error) {
      _notice(error.message);
    } catch (error) {
      _notice(ApiErrorResolver.message(error,
          fallback: 'Haven could not update your profile photo.'));
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  void _notice(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: const HavenNavigationBar(title: 'Personal information'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
                children: [
                  _ProfileHeader(
                    imageUrl: _profileImageUrl,
                    uploading: _uploadingPhoto,
                    onChangePhoto: _pickImage,
                  ),
                  const SizedBox(height: 26),
                  const _SectionHeading(
                    title: 'About you',
                    subtitle:
                        'The essentials attached to your Haven Zambia account.',
                  ),
                  const SizedBox(height: 12),
                  _FormCard(children: [
                    Row(children: [
                      Expanded(
                        child: _field(
                          controller: _firstName,
                          label: 'First name',
                          icon: Icons.person_outline_rounded,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _field(
                          controller: _lastName,
                          label: 'Last name',
                        ),
                      ),
                    ]),
                    const SizedBox(height: 14),
                    _field(
                      controller: _email,
                      label: 'Email address',
                      icon: Icons.mail_outline_rounded,
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        final missing = _required(value);
                        if (missing != null) return missing;
                        return value!.contains('@')
                            ? null
                            : 'Enter a valid email address';
                      },
                    ),
                    const SizedBox(height: 14),
                    _field(
                      controller: _phone,
                      label: 'Phone number',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                    ),
                  ]),
                  const SizedBox(height: 26),
                  const _SectionHeading(
                    title: 'WhatsApp contact',
                    subtitle:
                        'Control how renters can reach you from your listings.',
                  ),
                  const SizedBox(height: 12),
                  _FormCard(children: [
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      secondary: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: colors.primaryContainer,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(Icons.chat_rounded,
                            color: colors.onPrimaryContainer),
                      ),
                      title: const Text('Available on WhatsApp',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text('Show a WhatsApp action on your listings.'),
                      ),
                      value: _whatsAppEnabled,
                      onChanged: (value) =>
                          setState(() => _whatsAppEnabled = value),
                    ),
                    if (_whatsAppEnabled) ...[
                      Divider(color: colors.outlineVariant),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: const Text('Use my phone number'),
                        subtitle: Text(_phone.text.trim().isEmpty
                            ? 'Add your phone number above'
                            : _phone.text.trim()),
                        value: _whatsAppSameAsPhone,
                        onChanged: (value) => setState(
                            () => _whatsAppSameAsPhone = value ?? true),
                      ),
                      if (!_whatsAppSameAsPhone) ...[
                        const SizedBox(height: 8),
                        _field(
                          controller: _whatsApp,
                          label: 'Different WhatsApp number',
                          hint: 'e.g. +260 97 123 4567',
                          icon: Icons.phone_in_talk_outlined,
                          keyboardType: TextInputType.phone,
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                                  ? 'Enter your WhatsApp number'
                                  : null,
                        ),
                      ],
                    ],
                  ]),
                  const SizedBox(height: 28),
                  ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 19,
                            height: 19,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_rounded),
                    label: Text(_saving ? 'Saving…' : 'Save changes'),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Your contact details are only shown where needed to support enquiries.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? hint,
    IconData? icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator ?? _required,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon == null ? null : Icon(icon),
      ),
    );
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _phone.dispose();
    _whatsApp.dispose();
    super.dispose();
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.imageUrl,
    required this.uploading,
    required this.onChangePhoto,
  });

  final String imageUrl;
  final bool uploading;
  final VoidCallback onChangePhoto;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          colors.primaryContainer.withValues(alpha: .8),
          colors.surfaceContainerLow,
        ]),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(children: [
        Stack(clipBehavior: Clip.none, children: [
          Container(
            width: 82,
            height: 82,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: colors.surface,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: colors.shadow.withValues(alpha: .12),
                  blurRadius: 18,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: ClipOval(
              child: CachedNetworkImage(
                imageUrl: ApiConfig.optimizedImageUrl(
                  imageUrl,
                  width: 360,
                  height: 360,
                  quality: 80,
                ),
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  color: colors.surfaceContainerHighest,
                ),
                errorWidget: (_, __, ___) => Icon(Icons.person_rounded,
                    size: 42, color: colors.onSurfaceVariant),
              ),
            ),
          ),
          Positioned(
            right: -4,
            bottom: -2,
            child: Material(
              color: colors.primary,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: uploading ? null : onChangePhoto,
                customBorder: const CircleBorder(),
                child: SizedBox(
                  width: 34,
                  height: 34,
                  child: uploading
                      ? Padding(
                          padding: const EdgeInsets.all(8),
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: colors.onPrimary),
                        )
                      : Icon(Icons.camera_alt_outlined,
                          size: 18, color: colors.onPrimary),
                ),
              ),
            ),
          ),
        ]),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Your Haven Zambia profile',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800, letterSpacing: -.3)),
              const SizedBox(height: 5),
              Text('Keep your identity and contact details current.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: colors.onSurfaceVariant)),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: uploading ? null : onChangePhoto,
                style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 34),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                icon: const Icon(Icons.photo_library_outlined, size: 17),
                label: const Text('Change photo'),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 4),
      Text(subtitle,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: colors.onSurfaceVariant)),
    ]);
  }
}

class _FormCard extends StatelessWidget {
  const _FormCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(children: children),
    );
  }
}

class _ProfileException implements Exception {
  const _ProfileException(this.message);
  final String message;
}
