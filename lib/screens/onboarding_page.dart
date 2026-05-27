import 'package:flutter/material.dart';

import '../design/rv_colors.dart';
import '../models/app_user.dart';
import '../widgets/rv_glass.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, required this.onComplete});

  final Future<void> Function(ProfileDraft draft) onComplete;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController(text: 'You');
  final _countryController = TextEditingController(text: 'India');
  final _cityController = TextEditingController(text: 'Mumbai');
  final _bioController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    _countryController.dispose();
    _cityController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _continue() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    widget.onComplete(
      ProfileDraft(
        username: _usernameController.text.trim(),
        country: _countryController.text.trim(),
        city: _cityController.text.trim(),
        bio: _bioController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 26, 20, 24),
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [RvColors.crimson, RvColors.hyperOrange],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: RvColors.crimson,
                        blurRadius: 24,
                        spreadRadius: -8,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.speed_rounded, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Text(
                  'Racers Vault',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: RvColors.text,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            RvGlass(
              padding: const EdgeInsets.all(18),
              glowColor: RvColors.crimson,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Create your spotter profile',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: RvColors.text,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Your city powers rarity, local leaderboards, and privacy-safe discovery clusters.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: RvColors.mutedText,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _usernameController,
                          decoration: const InputDecoration(
                            labelText: 'Username',
                            prefixIcon: Icon(Icons.alternate_email_rounded),
                          ),
                          textInputAction: TextInputAction.next,
                          validator: _required,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _bioController,
                          decoration: const InputDecoration(
                            labelText: 'Bio',
                            prefixIcon: Icon(Icons.edit_note_rounded),
                          ),
                          maxLength: 160,
                          maxLines: 2,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _countryController,
                          decoration: const InputDecoration(
                            labelText: 'Country',
                            prefixIcon: Icon(Icons.flag_rounded),
                          ),
                          textInputAction: TextInputAction.next,
                          validator: _required,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _cityController,
                          decoration: const InputDecoration(
                            labelText: 'City',
                            prefixIcon: Icon(Icons.location_city_rounded),
                          ),
                          textInputAction: TextInputAction.done,
                          validator: _required,
                          onFieldSubmitted: (_) => _continue(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _continue,
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: const Text('Enter Racers Vault'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const _OnboardingFeature(
              icon: Icons.add_a_photo_rounded,
              title: 'Post real car spots',
              body:
                  'Start with manual car details, then upgrade to media upload.',
            ),
            const _OnboardingFeature(
              icon: Icons.bolt_rounded,
              title: 'Earn rarity points',
              body: 'Every spot gets a score based on rarity tier.',
            ),
            const _OnboardingFeature(
              icon: Icons.emoji_events_rounded,
              title: 'Climb local ranks',
              body:
                  'Country and city leaderboards become the competitive layer.',
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

class _OnboardingFeature extends StatelessWidget {
  const _OnboardingFeature({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: RvGlass(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, color: RvColors.electricBlue),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: RvColors.text,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(body, style: const TextStyle(color: RvColors.mutedText)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
