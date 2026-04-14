import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../home/home.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _months = 12;
  bool _cloud = false;
  final _backendCtrl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _backendCtrl.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final config = ref.read(appConfigProvider);
    final googleSignIn = ref.read(googleSignInProvider);
    await config.setSyncWindowMonths(_months);
    await config.setAllowCloudParse(_cloud);
    await config.setParseBackendUrl(_backendCtrl.text.trim().isEmpty
        ? null
        : _backendCtrl.text.trim());
    final user =
        googleSignIn.currentUser ?? await googleSignIn.signIn();
    if (user == null) {
      setState(() {
        _busy = false;
        _error = 'Google sign-in was cancelled.';
      });
      return;
    }
    await config.setOnboardingDone(true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('Fin Alert', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Built for India first (INR, UPI, NEFT/IMPS). Read-only Gmail access '
              'finds bank and wallet alerts; only snippets and headers are parsed on '
              'this device. Optional cloud parsing sends snippets to your backend '
              'only if you enable it — API keys and Hugging Face tokens stay on the server.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            Text('Historical sync window', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 3, label: Text('3 mo')),
                ButtonSegment(value: 6, label: Text('6 mo')),
                ButtonSegment(value: 12, label: Text('1 yr')),
                ButtonSegment(value: 120, label: Text('All')),
              ],
              selected: {_months},
              onSelectionChanged: (s) => setState(() => _months = s.first),
            ),
            const SizedBox(height: 24),
            SwitchListTile(
              title: const Text('Allow cloud parsing'),
              subtitle: const Text(
                'Uses your configured backend; never stores HF tokens in the app.',
              ),
              value: _cloud,
              onChanged: (v) => setState(() => _cloud = v),
            ),
            if (_cloud) ...[
              TextField(
                controller: _backendCtrl,
                decoration: const InputDecoration(
                  labelText: 'Parse backend base URL',
                  hintText: 'http://10.0.2.2:8787',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.url,
                autocorrect: false,
              ),
              const SizedBox(height: 16),
            ],
            if (_error != null) ...[
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              const SizedBox(height: 8),
            ],
            FilledButton(
              onPressed: _busy ? null : _finish,
              child: _busy
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Connect Gmail & continue'),
            ),
          ],
        ),
      ),
    );
  }
}
