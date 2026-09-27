import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../domain/engines/advice.dart';
import '../domain/engines/advisor_engine.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import 'main_shell.dart';

/// The SaveWise advisor.
///
/// It is a chat, but there is no model and no network behind it: every answer is
/// computed by [AdvisorEngine] from the user's own stored numbers. That is what
/// lets the brief's two hard promises hold at once — real financial coaching,
/// and nothing ever leaving the device.
class AdvisorScreen extends StatefulWidget {
  const AdvisorScreen({super.key});

  @override
  State<AdvisorScreen> createState() => _AdvisorScreenState();
}

class _AdvisorScreenState extends State<AdvisorScreen> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _toBottom());
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _toBottom() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      _scroll.position.maxScrollExtent,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void _send([String? preset]) {
    final String text = (preset ?? _input.text).trim();
    if (text.isEmpty) return;
    context.read<AppState>().ask(text);
    _input.clear();
    HapticFeedback.selectionClick();
    WidgetsBinding.instance.addPostFrameCallback((_) => _toBottom());
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = context.watch<AppState>();
    final List<ChatMessage> chat = state.chat;
    final List<String> suggestions = state.suggestedQuestions;

    return Scaffold(
      backgroundColor: AppColors.ink,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            _Header(score: state.score.total),
            Expanded(
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(
                    AppTheme.gutter, 10, AppTheme.gutter, 14),
                physics: const BouncingScrollPhysics(),
                children: <Widget>[
                  const _PrivacyNote(),
                  const SizedBox(height: 14),
                  for (final ChatMessage m in chat)
                    _Bubble(message: m, onAction: () => _act(m.action)),
                  if (state.insights.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 8),
                    _Insights(insights: state.insights),
                  ],
                ],
              ),
            ),
            if (suggestions.isNotEmpty)
              _Suggestions(questions: suggestions, onTap: _send),
            _Composer(
              controller: _input,
              focus: _focus,
              onSend: _send,
              onReset: () {
                context.read<AppState>().resetChat();
                WidgetsBinding.instance.addPostFrameCallback((_) => _toBottom());
              },
            ),
          ],
        ),
      ),
    );
  }

  void _act(AdviceAction action) {
    if (action == AdviceAction.none) return;
    ShellNav.go(context, action);
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppTheme.gutter, 14, AppTheme.gutter, 8),
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded),
            color: AppColors.textSecondary,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          const SizedBox(width: 8),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: AppColors.emeraldSweep,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.auto_awesome_rounded,
                size: 18, color: AppColors.textOnAccent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('${AppConstants.appName} Advisor',
                    style: AppTextStyles.cardTitle),
                const SizedBox(height: 2),
                Text(
                  'Knows your numbers · score $score/100',
                  style: AppTextStyles.small,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.slate,
        borderRadius: BorderRadius.circular(AppTheme.radiusControl),
        border: Border.all(color: AppColors.hairlineSoft),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.lock_outline_rounded,
              size: 14, color: AppColors.textMuted),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'Answers are worked out on this phone from your own data. Nothing '
              'is sent anywhere.',
              style: AppTextStyles.small.copyWith(
                fontSize: 11,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One chat bubble. The advisor's replies can carry supporting numbers and a
/// single action, so the conversation ends in something the user can do.
class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.onAction});

  final ChatMessage message;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final bool mine = message.fromUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: <Widget>[
          if (!mine) ...<Widget>[
            Container(
              width: 26,
              height: 26,
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: AppColors.emerald.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(Icons.auto_awesome_rounded,
                  size: 13, color: AppColors.emerald),
            ),
            const SizedBox(width: 9),
          ],
          Flexible(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 320),
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: mine ? AppColors.emeraldDeep : AppColors.slateHigh,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(mine ? 16 : 5),
                  bottomRight: Radius.circular(mine ? 5 : 16),
                ),
                border: Border.all(
                  color: mine ? Colors.transparent : AppColors.hairline,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    message.text,
                    style: AppTextStyles.body.copyWith(
                      height: 1.45,
                      color: mine
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                  if (message.bullets.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 10),
                    for (final String b in message.bullets)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Container(
                              width: 4,
                              height: 4,
                              margin: const EdgeInsets.only(top: 6, right: 8),
                              decoration: const BoxDecoration(
                                color: AppColors.emerald,
                                shape: BoxShape.circle,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                b,
                                style: AppTextStyles.small.copyWith(
                                  height: 1.4,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                  if (message.action != AdviceAction.none) ...<Widget>[
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: onAction,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: AppColors.emerald.withValues(alpha: 0.14),
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusPill),
                          border: Border.all(
                            color: AppColors.emerald.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              message.action.label,
                              style: AppTextStyles.small.copyWith(
                                color: AppColors.emeraldSoft,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_forward_rounded,
                                size: 13, color: AppColors.emeraldSoft),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    Dates.clock(message.at),
                    style: AppTextStyles.label.copyWith(
                      fontSize: 8.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Standing observations, always visible under the conversation. They answer
/// the questions the user has not thought to ask yet.
class _Insights extends StatelessWidget {
  const _Insights({required this.insights});

  final List<String> insights;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      dim: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.insights_rounded,
                  size: 14, color: AppColors.brass),
              const SizedBox(width: 8),
              Text('WHAT I NOTICE', style: AppTextStyles.label),
            ],
          ),
          const SizedBox(height: 10),
          for (final String line in insights)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Padding(
                    padding: EdgeInsets.only(top: 2, right: 8),
                    child: Icon(Icons.chevron_right_rounded,
                        size: 14, color: AppColors.brass),
                  ),
                  Expanded(
                    child: Text(
                      line,
                      style: AppTextStyles.small.copyWith(height: 1.4),
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

class _Suggestions extends StatelessWidget {
  const _Suggestions({required this.questions, required this.onTap});

  final List<String> questions;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.gutter),
        children: <Widget>[
          for (final String q in questions)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: GestureDetector(
                  onTap: () => onTap(q),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 13, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.slateHigh,
                      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                      border: Border.all(color: AppColors.hairline),
                    ),
                    child: Text(
                      q,
                      style: AppTextStyles.small
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focus,
    required this.onSend,
    required this.onReset,
  });

  final TextEditingController controller;
  final FocusNode focus;
  final void Function([String? preset]) onSend;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppTheme.gutter,
        10,
        AppTheme.gutter,
        MediaQuery.viewInsetsOf(context).bottom +
            MediaQuery.paddingOf(context).bottom +
            12,
      ),
      decoration: const BoxDecoration(
        color: AppColors.inkLift,
        border: Border(top: BorderSide(color: AppColors.hairlineSoft)),
      ),
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: onReset,
            tooltip: 'Start over',
            icon: const Icon(Icons.refresh_rounded, size: 19),
            color: AppColors.textMuted,
          ),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focus,
              style: AppTextStyles.body,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              minLines: 1,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Ask about your money…',
                hintStyle:
                    AppTextStyles.body.copyWith(color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.slateHigh,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  borderSide: const BorderSide(color: AppColors.hairline),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  borderSide: const BorderSide(color: AppColors.hairline),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  borderSide: const BorderSide(color: AppColors.emerald),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => onSend(),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: AppColors.emeraldSweep,
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              ),
              child: const Icon(Icons.send_rounded,
                  size: 18, color: AppColors.textOnAccent),
            ),
          ),
        ],
      ),
    );
  }
}
