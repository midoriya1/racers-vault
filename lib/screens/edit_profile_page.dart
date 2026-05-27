import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../design/rv_colors.dart';
import '../models/app_user.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/rv_glass.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key, required this.currentUser});

  final AppUser currentUser;

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  late final TextEditingController _usernameController;
  late final TextEditingController _countryController;
  late final TextEditingController _cityController;
  late final TextEditingController _bioController;
  String? _avatarLocalPath;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(
      text: widget.currentUser.username,
    );
    _countryController = TextEditingController(
      text: widget.currentUser.country,
    );
    _cityController = TextEditingController(text: widget.currentUser.city);
    _bioController = TextEditingController(text: widget.currentUser.bio);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _countryController.dispose();
    _cityController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 900,
      maxHeight: 900,
      imageQuality: 88,
    );
    if (image == null) {
      return;
    }
    setState(() {
      _avatarLocalPath = image.path;
    });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    Navigator.of(context).pop(
      ProfileDraft(
        username: _usernameController.text.trim(),
        country: _countryController.text.trim(),
        city: _cityController.text.trim(),
        bio: _bioController.text.trim(),
        avatarUrl: widget.currentUser.avatarUrl,
        avatarLocalPath: _avatarLocalPath,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            RvGlass(
              padding: const EdgeInsets.all(18),
              glowColor: RvColors.crimson,
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    ProfileAvatar(
                      username: _usernameController.text,
                      avatarUrl: widget.currentUser.avatarUrl,
                      localPath: _avatarLocalPath,
                      radius: 48,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _pickAvatar,
                      icon: const Icon(Icons.photo_camera_rounded),
                      label: const Text('Choose profile photo'),
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        prefixIcon: Icon(Icons.alternate_email_rounded),
                      ),
                      validator: _required,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _bioController,
                      decoration: const InputDecoration(
                        labelText: 'Bio',
                        prefixIcon: Icon(Icons.edit_note_rounded),
                      ),
                      maxLines: 3,
                      maxLength: 160,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _countryController,
                      decoration: const InputDecoration(
                        labelText: 'Country',
                        prefixIcon: Icon(Icons.flag_rounded),
                      ),
                      validator: _required,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _cityController,
                      decoration: const InputDecoration(
                        labelText: 'City',
                        prefixIcon: Icon(Icons.location_city_rounded),
                      ),
                      validator: _required,
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _save,
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('Save profile'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Required';
    }
    return null;
  }
}
