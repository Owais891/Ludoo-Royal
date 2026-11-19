import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/storage/app_config.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/services/profile_service.dart';

final _profileServiceProvider =
    Provider<ProfileService>((ref) => ProfileService());

/// Edit Profile screen — preloaded form to update identity fields.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _avatarController = TextEditingController();
  final _countryController = TextEditingController();
  final _bioController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _avatarController.dispose();
    _countryController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final u = await ref.read(_profileServiceProvider).fetchProfile();
      if (!mounted) return;
      _fullNameController.text = u.fullName;
      _avatarController.text = u.avatarUrl ?? '';
      _countryController.text = u.countryCode ?? '';
      _bioController.text = u.bio ?? '';
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      // Pre-fill with whatever AppConfig has so the user can still edit.
      _fullNameController.text = AppConfig.username ?? '';
      setState(() {
        _loading = false;
        _loadError = e.toString();
      });
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      final svc = ref.read(_profileServiceProvider);
      await svc.updateProfile(
        fullName: _fullNameController.text.trim(),
        avatarUrl: _avatarController.text.trim(),
        countryCode: _countryController.text.trim().toUpperCase(),
        bio: _bioController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: const Text('Profile updated successfully'),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(12),
          ),
        );
      context.go('/profile');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Update failed: ${_humanError(e)}'),
            backgroundColor: AppTheme.danger,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(12),
          ),
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _humanError(Object e) {
    final msg = e.toString();
    final m = RegExp(r"ApiException\(\d+\):\s*(.*)").firstMatch(msg);
    return m != null ? m.group(1)! : msg;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => context.go('/profile'),
        ),
        title: const Text('Edit Profile'),
      ),
      body: _loading
          ? _buildSkeleton()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_loadError != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.danger.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppTheme.danger.withOpacity(0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded,
                                color: AppTheme.danger, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Could not load latest profile. You can still edit locally.',
                                style: TextStyle(
                                    color: AppTheme.danger, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    _LabeledField(
                      label: 'Full Name',
                      child: TextFormField(
                        controller: _fullNameController,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          hintText: 'e.g. Royal Player',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (v) {
                          final s = v?.trim() ?? '';
                          if (s.isEmpty) return 'Full name is required';
                          if (s.length < 2) return 'Name is too short';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 14),
                    _LabeledField(
                      label: 'Avatar URL',
                      child: TextFormField(
                        controller: _avatarController,
                        keyboardType: TextInputType.url,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          hintText: 'https://example.com/avatar.png',
                          prefixIcon: Icon(Icons.image_outlined),
                        ),
                        validator: (v) {
                          final s = v?.trim() ?? '';
                          if (s.isEmpty) return null;
                          final uri = Uri.tryParse(s);
                          if (uri == null || !uri.isAbsolute) {
                            return 'Please enter a valid URL';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 14),
                    _LabeledField(
                      label: 'Country Code',
                      child: TextFormField(
                        controller: _countryController,
                        textCapitalization: TextCapitalization.characters,
                        maxLength: 3,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          hintText: 'e.g. US, PK, GB',
                          prefixIcon: Icon(Icons.flag_outlined),
                          counterText: '',
                        ),
                        validator: (v) {
                          final s = v?.trim() ?? '';
                          if (s.isEmpty) return null;
                          if (!RegExp(r'^[A-Z]{2,3}$').hasMatch(s)) {
                            return 'Use 2-3 letters only';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 14),
                    _LabeledField(
                      label: 'Bio',
                      child: TextFormField(
                        controller: _bioController,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        maxLines: 4,
                        minLines: 3,
                        maxLength: 240,
                        decoration: const InputDecoration(
                          hintText: 'Tell other players something about you…',
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 54,
                      child: _SaveButton(
                        loading: _saving,
                        onPressed: _save,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSkeleton() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: List.generate(
        5,
        (_) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Container(
            height: 70,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final Widget child;

  const _LabeledField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _SaveButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onPressed;
  const _SaveButton({required this.loading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: loading ? 0.75 : 1.0,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: loading ? null : onPressed,
          child: Ink(
            decoration: BoxDecoration(
              gradient: AppTheme.goldGradient(),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFC107).withOpacity(0.30),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Container(
              alignment: Alignment.center,
              child: loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.black,
                      ),
                    )
                  : const Text(
                      'Save Changes',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
