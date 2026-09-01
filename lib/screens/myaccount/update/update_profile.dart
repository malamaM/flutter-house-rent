import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:house_rent/config/api_config.dart';
import 'package:house_rent/services/app_data_service.dart';
import 'package:house_rent/services/api_error.dart';
import 'package:house_rent/services/media_upload_policy.dart';
import 'package:house_rent/services/session_token_store.dart';
import 'package:house_rent/widgets/haven_navigation_bar.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

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
      final token = await SessionTokenStore.read();
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
      final token = await SessionTokenStore.read();
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
          ? const Center(child: CupertinoActivityIndicator(radius: 13))
          : Form(
              key: _formKey,
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
                children: [
                  _ProfileHeader(
                    imageUrl: _profileImageUrl,
                    uploading: _uploadingPhoto,
                    onChangePhoto: _pickImage,
                  ),
                  const SizedBox(height: 22),
                  const _SectionHeading(
                    title: 'ABOUT YOU',
                    subtitle: 'The essentials attached to your account.',
                  ),
                  const SizedBox(height: 8),
                  _FormCard(children: [
                    _field(
                      controller: _firstName,
                      label: 'First name',
                      icon: CupertinoIcons.person,
                    ),
                    _FormDivider(color: colors.outlineVariant),
                    _field(
                      controller: _lastName,
                      label: 'Last name',
                      icon: CupertinoIcons.person,
                    ),
                    _FormDivider(color: colors.outlineVariant),
                    _field(
                      controller: _email,
                      label: 'Email',
                      icon: CupertinoIcons.mail,
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        final missing = _required(value);
                        if (missing != null) return missing;
                        return value!.contains('@')
                            ? null
                            : 'Enter a valid email address';
                      },
                    ),
                    _FormDivider(color: colors.outlineVariant),
                    _field(
                      controller: _phone,
                      label: 'Phone',
                      icon: CupertinoIcons.phone,
                      keyboardType: TextInputType.phone,
                    ),
                  ]),
                  const SizedBox(height: 22),
                  const _SectionHeading(
                    title: 'WHATSAPP CONTACT',
                    subtitle:
                        'Control how renters can reach you from your listings.',
                  ),
                  const SizedBox(height: 8),
                  _FormCard(children: [
                    CupertinoListTile(
                      padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
                      leading: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: colors.primaryContainer,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Icon(CupertinoIcons.chat_bubble_fill,
                            size: 18, color: colors.onPrimaryContainer),
                      ),
                      title: const Text('Available on WhatsApp'),
                      subtitle:
                          const Text('Show a WhatsApp button on your listings'),
                      trailing: CupertinoSwitch(
                        value: _whatsAppEnabled,
                        activeTrackColor: colors.primary,
                        onChanged: (value) =>
                            setState(() => _whatsAppEnabled = value),
                      ),
                    ),
                    if (_whatsAppEnabled) ...[
                      _FormDivider(color: colors.outlineVariant),
                      CupertinoListTile(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                        onTap: () => setState(
                            () => _whatsAppSameAsPhone = !_whatsAppSameAsPhone),
                        title: const Text('Use my phone number'),
                        subtitle: Text(
                          _phone.text.trim().isEmpty
                              ? 'Add your phone number above'
                              : _phone.text.trim(),
                        ),
                        trailing: AnimatedOpacity(
                          duration: const Duration(milliseconds: 140),
                          opacity: _whatsAppSameAsPhone ? 1 : 0,
                          child: Icon(CupertinoIcons.check_mark,
                              size: 20, color: colors.primary),
                        ),
                      ),
                      if (!_whatsAppSameAsPhone) ...[
                        _FormDivider(color: colors.outlineVariant),
                        _field(
                          controller: _whatsApp,
                          label: 'WhatsApp',
                          hint: '+260 97 123 4567',
                          icon: CupertinoIcons.phone_badge_plus,
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
                  CupertinoButton.filled(
                    borderRadius: BorderRadius.circular(14),
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const CupertinoActivityIndicator(
                            color: CupertinoColors.white)
                        : const Text('Save changes'),
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
    final colors = Theme.of(context).colorScheme;
    return CupertinoTextFormFieldRow(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator ?? _required,
      placeholder: hint ?? label,
      textInputAction: keyboardType == TextInputType.emailAddress
          ? TextInputAction.next
          : TextInputAction.next,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      prefix: SizedBox(
        width: 112,
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: colors.primary),
              const SizedBox(width: 10),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: colors.onSurface, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
      style: TextStyle(color: colors.onSurface, fontSize: 16),
      placeholderStyle: TextStyle(color: colors.onSurfaceVariant, fontSize: 16),
      decoration: const BoxDecoration(),
      autovalidateMode: AutovalidateMode.onUserInteraction,
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
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: colors.outlineVariant.withValues(alpha: .55), width: .5),
      ),
      child: Column(children: [
        GestureDetector(
          onTap: uploading ? null : onChangePhoto,
          child: Stack(clipBehavior: Clip.none, children: [
            Container(
              width: 88,
              height: 88,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: colors.surface,
                shape: BoxShape.circle,
                border: Border.all(
                    color: colors.outlineVariant.withValues(alpha: .7)),
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
                  errorWidget: (_, __, ___) => Icon(CupertinoIcons.person_fill,
                      size: 42, color: colors.onSurfaceVariant),
                ),
              ),
            ),
            Positioned(
              right: -3,
              bottom: -2,
              child: Container(
                width: 31,
                height: 31,
                decoration: BoxDecoration(
                  color: colors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.surface, width: 2),
                ),
                child: uploading
                    ? const CupertinoActivityIndicator(
                        radius: 7, color: CupertinoColors.white)
                    : Icon(CupertinoIcons.camera_fill,
                        size: 15, color: colors.onPrimary),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 7),
        CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          minimumSize: const Size(0, 32),
          onPressed: uploading ? null : onChangePhoto,
          child: const Text('Change Photo'),
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
          style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: .2)),
      const SizedBox(height: 4),
      Text(subtitle,
          style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13)),
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
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: colors.outlineVariant.withValues(alpha: .55), width: .5),
      ),
      child: Column(children: children),
    );
  }
}

class _FormDivider extends StatelessWidget {
  const _FormDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 48),
        child: Container(
          height: .5,
          color: color.withValues(alpha: .65),
        ),
      );
}

class _ProfileException implements Exception {
  const _ProfileException(this.message);
  final String message;
}
