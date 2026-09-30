import 'package:flutter/material.dart';
import '../../data/pulse_store.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../../widgets/pulse_components.dart';

/// ═══════════════════════════════════════════════════════════════════
/// BOARD 02 — Authentication. Splash · Welcome · Login · Sign Up ·
/// Forgot Password. Flow A entry states, full validation (§75).
/// ═══════════════════════════════════════════════════════════════════

// ── 1. Splash ──────────────────────────────────────────────────────
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: PulseDuration.slow)..forward();

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (!mounted) return;
      // No captured profile yet → onboarding, never the sample dashboard.
      final next = context.pulse.hasProfile ? '/home' : '/welcome';
      Navigator.of(context).pushReplacementNamed(next);
    });
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? PulseColors.darkBg : PulseColors.primary,
      body: SafeArea(
        child: Center(
          child: FadeTransition(
            opacity: CurvedAnimation(parent: _c, curve: Curves.easeOut),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Original brand mark: a pulse-wave inside a ring.
              AnimatedBuilder(
                animation: _c,
                builder: (_, __) => CustomPaint(painter: _SplashPulse(progress: _c.value), size: const Size(96, 96)),
              ),
              const SizedBox(height: PulseSpacing.l),
              Text('PULSE',
                  style: TextStyle(
                      fontSize: 40, fontWeight: FontWeight.w800, letterSpacing: 8,
                      color: isDark ? PulseColors.darkText : Colors.white)),
              const SizedBox(height: PulseSpacing.s),
              Text('Eat better. Move better. Get stronger.',
                  style: TextStyle(fontSize: 15.5, color: (isDark ? Colors.white70 : Colors.white70))),
            ]),
          ),
        ),
      ),
    );
  }
}

class _SplashPulse extends CustomPainter {
  _SplashPulse({required this.progress});
  final double progress;
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 6;
    canvas.drawCircle(c, r, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = Colors.white.withOpacity(0.35));
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.4
      ..strokeCap = StrokeCap.round
      ..color = Colors.white;
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), -1.9, 3.8 * progress, false, arc);
    // heartbeat line
    final path = Path()
      ..moveTo(c.dx - r * 0.62, c.dy)
      ..lineTo(c.dx - r * 0.28, c.dy)
      ..lineTo(c.dx - r * 0.12, c.dy - r * 0.34)
      ..lineTo(c.dx + 0.04 * r, c.dy + r * 0.3)
      ..lineTo(c.dx + 0.18 * r, c.dy - r * 0.12)
      ..lineTo(c.dx + 0.3, c.dy)
      ..lineTo(c.dx + r * 0.62, c.dy);
    canvas.drawPath(path, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _SplashPulse old) => old.progress != progress;
}

// ── Shared social buttons ──────────────────────────────────────────
class SocialButtons extends StatelessWidget {
  const SocialButtons({super.key});
  @override
  Widget build(BuildContext context) => Column(children: [
        _socialRow(context, Icons.apple_rounded, 'Continue with Apple'),
        const SizedBox(height: PulseSpacing.s),
        _socialRow(context, Icons.g_mobiledata_rounded, 'Continue with Google'),
      ]);

  Widget _socialRow(BuildContext context, IconData icon, String label) => SecondaryButton(
      label: label,
      icon: icon,
      onTap: () {
        context.pulse.track('social_login_tapped', {'provider': label});
        Navigator.of(context).pushReplacementNamed('/onboarding-goals');
      });
}

class OrDivider extends StatelessWidget {
  const OrDivider({super.key, this.label = 'or'});
  final String label;
  @override
  Widget build(BuildContext context) => Row(children: [
        const Expanded(child: Divider()),
        Padding(padding: const EdgeInsets.symmetric(horizontal: PulseSpacing.m),
            child: Text(label, style: Theme.of(context).textTheme.labelMedium)),
        const Expanded(child: Divider()),
      ]);
}

// ── 2. Welcome ─────────────────────────────────────────────────────
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Stack(fit: StackFit.expand, children: [
        // "Photography" placeholder: layered abstract wellness gradient scene
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: scheme.brightness == Brightness.dark
                  ? [const Color(0xFF0B2A25), const Color(0xFF123A34), PulseColors.darkBg]
                  : [const Color(0xFF0E7C6B), const Color(0xFF14919B), const Color(0xFFD3EDE6)],
            ),
          ),
        ),
        CustomPaint(painter: _WelcomeRings(), size: MediaQuery.sizeOf(context)),
        SafeArea(
          child: Column(children: [
            const Spacer(flex: 3),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: PulseSpacing.xl),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Build a healthier life,\none day at a time.',
                    style: TextStyle(fontSize: 34, height: 1.18, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.8)),
                const SizedBox(height: PulseSpacing.m),
                Text('Track nutrition, workouts, activity and progress in one simple place.',
                    style: TextStyle(fontSize: 16, height: 1.5, color: Colors.white.withOpacity(0.9))),
              ]),
            ),
            const Spacer(flex: 2),
            Padding(
              padding: const EdgeInsets.fromLTRB(PulseSpacing.xl, 0, PulseSpacing.xl, PulseSpacing.l),
              child: Column(children: [
                FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: Colors.white, foregroundColor: PulseColors.primaryDark,
                        minimumSize: const Size(double.infinity, 54)),
                    onPressed: () {
                      context.pulse.track('onboarding_started');
                      Navigator.of(context).pushNamed('/signup');
                    },
                    child: const Text('Get Started')),
                const SizedBox(height: PulseSpacing.s),
                OutlinedButton(
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white, side: BorderSide(color: Colors.white.withOpacity(0.7), width: 1.4),
                        minimumSize: const Size(double.infinity, 54)),
                    onPressed: () => Navigator.of(context).pushNamed('/login'),
                    child: const Text('I already have an account')),
                const SizedBox(height: PulseSpacing.m),
                const SocialButtons(),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _WelcomeRings extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.white.withOpacity(0.12);
    for (var i = 0; i < 4; i++) {
      p.strokeWidth = 1.2 + i;
      canvas.drawCircle(Offset(size.width * 0.85, size.height * 0.16), 60.0 + i * 46, p);
    }
    canvas.drawCircle(Offset(size.width * 0.1, size.height * 0.72), 120, p..color = Colors.white.withOpacity(0.07));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── 3. Sign Up (§13) ───────────────────────────────────────────────
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});
  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _showPassword = false;
  bool _acceptedTerms = false;

  /// A create-account request is in flight. Only ever true while something is
  /// actually happening, so the button cannot spin forever (§75).
  bool _submitting = false;

  /// The user has attempted to submit at least once. Validation messages stay
  /// hidden until then: an untouched form must not open with three errors.
  bool _attempted = false;

  /// Focus is held explicitly so it can be released before navigating away.
  /// Without this the platform keeps the old field registered as the input
  /// target and a later tap on it raises no keyboard.
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  String? get _emailError {
    if (!_attempted) return null;
    final v = _email.text.trim();
    if (v.isEmpty) return 'Enter your email address';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)) return 'Enter a valid email address';
    return null;
  }

  String? get _passwordError {
    if (!_attempted) return null;
    final v = _password.text;
    if (v.isEmpty) return 'Create a password';
    if (v.length < 8) return 'Use at least 8 characters';
    return null;
  }

  /// Validity independent of whether messages are being shown, so the button
  /// knows what to do before the first attempt.
  bool get _isValid {
    final e = _email.text.trim();
    return e.isNotEmpty &&
        RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(e) &&
        _password.text.length >= 8 &&
        _acceptedTerms;
  }

  /// Hands focus back to the platform before leaving, so the next screen —
  /// or this one, revisited — can raise the keyboard normally.
  void _releaseFocus() {
    _emailFocus.unfocus();
    _passwordFocus.unfocus();
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit(PulseStore store) async {
    // First attempt switches the messages on; an invalid form stops here with
    // the reasons visible and no spinner left running.
    setState(() => _attempted = true);
    if (!_isValid) return;

    _releaseFocus();
    setState(() => _submitting = true);
    store.track('signup_completed');
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    // Clear before navigating so returning to this screen finds a live button.
    setState(() => _submitting = false);
    Navigator.of(context).pushReplacementNamed('/onboarding-goals');
  }

  @override
  Widget build(BuildContext context) {
    final store = context.pulse;
    return PulseScaffold(
      title: '',
      body: ListView(padding: const EdgeInsets.fromLTRB(PulseSpacing.xl, 0, PulseSpacing.xl, PulseSpacing.huge), children: [
        Text('Create your PULSE account', style: Theme.of(context).textTheme.displaySmall),
        const SizedBox(height: PulseSpacing.s),
        Text('Free forever for core tracking. You can set up your plan in two minutes.',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: PulseSpacing.xl),
        const SocialButtons(),
        const SizedBox(height: PulseSpacing.l),
        const OrDivider(label: 'or sign up with email'),
        const SizedBox(height: PulseSpacing.l),
        TextField(
          controller: _email,
          focusNode: _emailFocus,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => _passwordFocus.requestFocus(),
          autofillHints: const [AutofillHints.email],
          decoration: InputDecoration(
            labelText: 'Email',
            hintText: 'you@example.com',
            prefixIcon: const Icon(Icons.alternate_email_rounded, size: 20),
            errorText: _emailError,
            suffixIcon: _emailError == null && _email.text.isNotEmpty
                ? const Icon(Icons.check_circle_rounded, color: PulseColors.success, size: 20)
                : null,
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: PulseSpacing.m),
        TextField(
          controller: _password,
          focusNode: _passwordFocus,
          obscureText: !_showPassword,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _releaseFocus(),
          autofillHints: const [AutofillHints.newPassword],
          decoration: InputDecoration(
            labelText: 'Password',
            helperText: 'At least 8 characters',
            helperMaxLines: 1,
            prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
            errorText: _passwordError,
            suffixIcon: IconButton(
              tooltip: _showPassword ? 'Hide password' : 'Show password',
              onPressed: () => setState(() => _showPassword = !_showPassword),
              icon: Icon(_showPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 20),
            ),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: PulseSpacing.m),
        // Terms acceptance — explicit, unticked by default (privacy by design §97)
        InkWell(
          borderRadius: BorderRadius.circular(PulseRadius.m),
          onTap: () => setState(() => _acceptedTerms = !_acceptedTerms),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: PulseSpacing.s),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Checkbox(value: _acceptedTerms, onChanged: (v) => setState(() => _acceptedTerms = v ?? false)),
              const SizedBox(width: PulseSpacing.s),
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('I agree to the ', style: Theme.of(context).textTheme.bodyMedium),
                    GestureDetector(
                        onTap: () => Navigator.of(context).pushNamed('/privacy'),
                        child: Text('Terms', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700, decoration: TextDecoration.underline))),
                    Text(' and ', style: Theme.of(context).textTheme.bodyMedium),
                    GestureDetector(
                        onTap: () => Navigator.of(context).pushNamed('/privacy'),
                        child: Text('Privacy Policy', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700, decoration: TextDecoration.underline))),
                    Text('.', style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
            ]),
          ),
        ),
        if (_attempted && !_acceptedTerms)
          Padding(
            padding: const EdgeInsets.only(bottom: PulseSpacing.s),
            child: Text('Please accept the Terms and Privacy Policy to continue.',
                style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 14)),
          ),
        const SizedBox(height: PulseSpacing.m),
        PrimaryButton(
            label: 'Create Account',
            loading: _submitting,
            // Always tappable: an invalid form reveals what is missing rather
            // than leaving a dead button the user cannot learn from (§75).
            onTap: _submitting ? null : () => _submit(store)),
        const SizedBox(height: PulseSpacing.m),
        Center(
          child: TextButton(
              onPressed: () {
                _releaseFocus();
                Navigator.of(context).pushReplacementNamed('/login');
              },
              child: const Text('I already have an account')),
        ),
      ]),
    );
  }
}

// ── 4. Login ───────────────────────────────────────────────────────
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController(text: 'pulsepass1');
  bool _show = false;

  @override
  void dispose() { _email.dispose(); _password.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final store = context.pulse;
    return PulseScaffold(
      title: '',
      body: ListView(padding: const EdgeInsets.fromLTRB(PulseSpacing.xl, 0, PulseSpacing.xl, PulseSpacing.huge), children: [
        Text('Welcome back', style: Theme.of(context).textTheme.displaySmall),
        const SizedBox(height: PulseSpacing.s),
        Text('Your streak is waiting for you — tomorrow is another opportunity to stay consistent.',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: PulseSpacing.xl),
        const SocialButtons(),
        const SizedBox(height: PulseSpacing.l),
        const OrDivider(label: 'or log in with email'),
        const SizedBox(height: PulseSpacing.l),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.alternate_email_rounded, size: 20)),
        ),
        const SizedBox(height: PulseSpacing.m),
        TextField(
          controller: _password,
          obscureText: !_show,
          decoration: InputDecoration(
            labelText: 'Password',
            prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
            suffixIcon: IconButton(
                onPressed: () => setState(() => _show = !_show),
                icon: Icon(_show ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 20)),
          ),
        ),
        Align(alignment: Alignment.centerRight,
            child: TextButton(onPressed: () => Navigator.of(context).pushNamed('/forgot-password'), child: const Text('Forgot password?'))),
        const SizedBox(height: PulseSpacing.s),
        PrimaryButton(label: 'Log In', icon: Icons.login_rounded, onTap: () {
          store.track('login_completed');
          Navigator.of(context).pushNamedAndRemoveUntil('/home', (r) => false);
        }),
        const SizedBox(height: PulseSpacing.m),
        Center(
          child: TextButton(onPressed: () => Navigator.of(context).pushReplacementNamed('/signup'),
              child: const Text('Create a new account')),
        ),
      ]),
    );
  }
}

// ── 5. Forgot Password ─────────────────────────────────────────────
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _email = TextEditingController();
  bool _sent = false;

  @override
  void dispose() { _email.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final valid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email.text.trim());
    return PulseScaffold(
      title: 'Reset password',
      body: ListView(padding: const EdgeInsets.all(PulseSpacing.xl), children: [
        if (!_sent) ...[
          Text('Enter the email tied to your PULSE account and we\'ll send a secure reset link.',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: PulseSpacing.l),
          TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                  labelText: 'Email',
                  errorText: _email.text.isNotEmpty && !valid ? 'Enter a valid email address' : null),
              onChanged: (_) => setState(() {})),
          const SizedBox(height: PulseSpacing.l),
          PrimaryButton(label: 'Send Reset Link', onTap: valid ? () => setState(() => _sent = true) : null),
        ] else ...[
          const EmptyState(
              icon: Icons.mark_email_read_rounded,
              title: 'Check your inbox',
              body: 'If an account exists for that address, a reset link is on its way. It expires in 30 minutes.'),
        ],
      ]),
    );
  }
}
