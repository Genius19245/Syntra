import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../auth/auth_service.dart';
import '../../../auth/widgets/sign_in_bar.dart';
import '../../../history/past_lessons_link.dart';
import '../../../theme/syntra_palette.dart';
import '../../../theme/syntra_theme.dart';
import '../../../widgets/syntra_button.dart';
import '../../../widgets/syntra_mark.dart';
import '../../../widgets/syntra_shell.dart';
import '../../auth/sign_in_screen.dart';

class LandingHero extends StatelessWidget {
  const LandingHero({
    super.key,
    required this.onCreate,
    required this.onOpenHistory,
  });

  final VoidCallback onCreate;
  final VoidCallback onOpenHistory;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 880;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SyntraPageFrame(
            padding: const EdgeInsets.fromLTRB(28, 12, 28, 0),
            child: SyntraTopBar(
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PastLessonsLink(onPressed: onOpenHistory),
                  const SignInBar(),
                ],
              ),
            ),
          ),
          Expanded(
            child: SyntraPageFrame(
              padding: const EdgeInsets.fromLTRB(28, 8, 28, 36),
              child: wide
                  ? Row(
                      children: [
                        Expanded(
                          flex: 6,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: _Copy(
                              onCreate: onCreate,
                              onOpenHistory: onOpenHistory,
                            ),
                          ),
                        ),
                        const SizedBox(width: 36),
                        const Expanded(flex: 5, child: _PreviewPanel()),
                      ],
                    )
                  : ListView(
                      children: [
                        _Copy(
                          onCreate: onCreate,
                          onOpenHistory: onOpenHistory,
                        ),
                        const SizedBox(height: 32),
                        const _PreviewPanel(),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Copy extends StatelessWidget {
  const _Copy({
    required this.onCreate,
    required this.onOpenHistory,
  });

  final VoidCallback onCreate;
  final VoidCallback onOpenHistory;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 620),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: SyntraPalette.rust.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'FOR TEACHERS  ·  EVERY SUBJECT',
                style: SyntraTheme.sans(
                  color: SyntraPalette.rust,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
            ).animate().fadeIn().slideY(begin: 0.2),
            const SizedBox(height: 22),
            Text(
              'Plan the lesson\nyou need tomorrow.',
              style: SyntraTheme.sans(
                color: SyntraPalette.navy,
                fontSize: MediaQuery.sizeOf(context).width >= 880 ? 64 : 42,
                fontWeight: FontWeight.w800,
                height: 0.98,
                letterSpacing: -2.2,
              ),
            ).animate().fadeIn(delay: 80.ms).slideY(begin: 0.08),
            const SizedBox(height: 18),
            Text(
              'SYNTRA researches the topic, checks the facts, and writes a curriculum a teacher can actually teach — at the right level, for the right board.',
              style: SyntraTheme.sans(
                color: SyntraPalette.inkMuted,
                fontSize: 18,
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ).animate().fadeIn(delay: 140.ms),
            const SizedBox(height: 32),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SyntraButton(
                  label: 'Create New Lesson',
                  icon: Icons.add,
                  onPressed: onCreate,
                ),
                SyntraButton(
                  label: 'Past lessons',
                  icon: Icons.history_rounded,
                  filled: false,
                  onPressed: onOpenHistory,
                ),
              ],
            ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.12),
            const _OptionalSignInHint(),
            const SizedBox(height: 28),
            Wrap(
              spacing: 18,
              runSpacing: 10,
              children: const [
                _TrustMark(label: 'Research'),
                _TrustMark(label: 'Fact-check'),
                _TrustMark(label: 'Curriculum'),
              ],
            ).animate().fadeIn(delay: 260.ms),
          ],
        ),
    );
  }
}

class _OptionalSignInHint extends StatelessWidget {
  const _OptionalSignInHint();

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.maybeOf(context);
    if (auth?.isSignedIn == true) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton(
            onPressed: () => openSignInPage(context, auth: auth),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              foregroundColor: SyntraPalette.rust,
            ),
            child: Text(
              'Sign in to keep lessons across devices',
              style: SyntraTheme.sans(
                color: SyntraPalette.rust,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
          Text(
            'Optional — skip and continue as a guest.',
            style: SyntraTheme.sans(
              color: SyntraPalette.inkMuted,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrustMark extends StatelessWidget {
  const _TrustMark({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: const BoxDecoration(
            color: SyntraPalette.rust,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: SyntraTheme.sans(
            color: SyntraPalette.navy,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class _PreviewPanel extends StatelessWidget {
  const _PreviewPanel();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: SyntraPalette.paper,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: SyntraPalette.stroke),
            boxShadow: [
              BoxShadow(
                color: SyntraPalette.navy.withValues(alpha: 0.08),
                blurRadius: 40,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const SyntraMark(size: 36),
                  const SizedBox(width: 12),
                  Text(
                    'Lesson brief',
                    style: SyntraTheme.sans(
                      color: SyntraPalette.navy,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: SyntraPalette.rust,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'READY',
                      style: SyntraTheme.sans(
                        color: SyntraPalette.onAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Physical Landscapes',
                style: SyntraTheme.sans(
                  color: SyntraPalette.navy,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'A GCSE Geography unit a teacher can walk into on Monday.',
                style: SyntraTheme.sans(
                  color: SyntraPalette.inkMuted,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: const [
                  _PreviewChip(label: 'Geography'),
                  _PreviewChip(label: 'GCSE'),
                  _PreviewChip(label: 'AQA'),
                ],
              ),
              const SizedBox(height: 22),
              _PreviewRow(
                title: 'Research',
                detail: 'Sources ranked and checked',
                done: true,
              ),
              _PreviewRow(
                title: 'Prerequisites',
                detail: 'What the class must already know',
                done: true,
              ),
              _PreviewRow(
                title: 'Curriculum',
                detail: 'Sequenced lessons, ready to teach',
                done: false,
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: 180.ms).slideX(begin: 0.04);
  }
}

class _PreviewChip extends StatelessWidget {
  const _PreviewChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: SyntraPalette.voidMid,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: SyntraTheme.sans(
          color: SyntraPalette.navy,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({
    required this.title,
    required this.detail,
    required this.done,
  });

  final String title;
  final String detail;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? SyntraPalette.rust : Colors.transparent,
              border: Border.all(
                color: done ? SyntraPalette.rust : SyntraPalette.strokeStrong,
              ),
            ),
            child: done
                ? const Icon(Icons.check, size: 13, color: SyntraPalette.onAccent)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: SyntraTheme.sans(
                    color: SyntraPalette.navy,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                Text(
                  detail,
                  style: SyntraTheme.sans(
                    color: SyntraPalette.inkMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
