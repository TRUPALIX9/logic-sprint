import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app.dart';
import '../core/config.dart';
import '../core/theme.dart';
import '../games/games.dart';
import '../models/round_result.dart';
import '../services/leaderboard.dart';
import '../ui/chamfer.dart';
import '../ui/kit.dart';

Route<void> resultRoute(RoundResult result) =>
    MaterialPageRoute<void>(builder: (_) => ResultScreen(result: result));

class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key, required this.result});

  final RoundResult result;

  @override
  Widget build(BuildContext context) {
    final game = result.game;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 48,
              ),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        GameTile(game: game, size: 44),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const DisplayText('Round complete', size: 26),
                              const SizedBox(height: 4),
                              MonoLabel(game.titleWith(result.difficulty)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(child: _ScoreCard(result: result)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _Stat('Correct', '${result.correct}', LS.teal),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _Stat('Wrong', '${result.wrong}', LS.coral),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _Stat(
                            'Accuracy',
                            '${result.accuracy}%',
                            LS.text,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _PostCard(result: result),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: SecondaryButton(
                            label: 'Home',
                            onPressed: () => Navigator.of(
                              context,
                            ).popUntil((route) => route.isFirst),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: PrimaryButton(
                            label: 'Play again',
                            icon: Icons.refresh_rounded,
                            onPressed: () =>
                                Navigator.of(context).pushReplacement(
                                  gameRoute(game, result.difficulty),
                                ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.result});

  final RoundResult result;

  @override
  Widget build(BuildContext context) {
    final accent = result.game.accent;
    return ChamferBox(
      cut: Cut.lg,
      borderColor: accent.withValues(alpha: 0.4),
      padding: const EdgeInsets.all(22),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const MonoLabel('Score'),
          const SizedBox(height: 12),
          Text(
            '${result.score}',
            style:
                LSText.mono(
                  88,
                  color: accent,
                  weight: FontWeight.w700,
                  spacing: 0,
                ).copyWith(
                  height: 1,
                  shadows: [
                    Shadow(
                      color: accent.withValues(alpha: 0.35),
                      blurRadius: 24,
                    ),
                  ],
                ),
          ),
          const SizedBox(height: 12),
          if (result.isNewBest)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              color: LS.blue,
              child: MonoLabel(
                'New best · +${result.improvement}',
                size: 12,
                weight: FontWeight.w700,
                color: LS.bg,
              ),
            )
          else
            MonoLabel(
              'Best ${math.max(result.score, result.previousBest)}',
              color: LS.dim,
            ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.color);

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ChamferBox(
      cut: Cut.sm,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MonoLabel(label, size: 10, color: LS.dim),
          const SizedBox(height: 6),
          Text(
            value,
            style: LSText.mono(
              22,
              color: color,
              weight: FontWeight.w700,
              spacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

/// Name field + Post to the global Top 10.
class _PostCard extends StatefulWidget {
  const _PostCard({required this.result});

  final RoundResult result;

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> {
  late final TextEditingController _name;
  bool _posting = false;
  bool _posted = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(
      text: context.read<Leaderboard>().savedName ?? '',
    );
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _post() async {
    final leaderboard = context.read<Leaderboard>();
    setState(() {
      _posting = true;
      _error = null;
    });
    final error = await leaderboard.submit(
      name: _name.text,
      game: widget.result.game,
      difficulty: widget.result.difficulty,
      score: widget.result.score,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _posting = false;
      _posted = error == null;
      _error = error;
    });
    if (error == null) {
      FocusScope.of(context).unfocus();
    }
  }

  void _seeRanks() {
    final tabs = context.read<NavTabs>();
    Navigator.of(context).popUntil((route) => route.isFirst);
    tabs.value = NavTabs.ranks;
  }

  @override
  Widget build(BuildContext context) {
    final postsLeft = context.read<Leaderboard>().postsLeftToday;
    final canPost = !_posting && widget.result.score > 0 && postsLeft > 0;
    final helper =
        _error ??
        (widget.result.score == 0
            ? 'Score above 0 to post'
            : '$postsLeft of ${AppConfig.maxDailySubmissions} posts left today');

    return ChamferBox(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MonoLabel('Post to Global Top 10'),
          const SizedBox(height: 10),
          if (_posted)
            Row(
              children: [
                const Icon(Icons.check_rounded, color: LS.teal),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Posted as ${_name.text.trim()}',
                    style: LSText.body(15),
                  ),
                ),
                TextButton(
                  onPressed: _seeRanks,
                  child: DisplayText('See ranks', size: 16, color: LS.teal),
                ),
              ],
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: ChamferBox(
                    cut: Cut.sm,
                    height: 48,
                    color: LS.surface2,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.person_outline_rounded,
                          size: 18,
                          color: LS.dim,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _name,
                            enabled: !_posting,
                            style: LSText.mono(
                              15,
                              color: LS.text,
                              spacing: 0.04,
                            ),
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(
                                AppConfig.maxPlayerNameLength,
                              ),
                            ],
                            textInputAction: TextInputAction.send,
                            onSubmitted: canPost ? (_) => _post() : null,
                            decoration: InputDecoration.collapsed(
                              hintText: 'Display name',
                              hintStyle: LSText.mono(
                                15,
                                color: LS.dim,
                                spacing: 0.04,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Opacity(
                  opacity: canPost ? 1 : 0.4,
                  child: ChamferBox(
                    cut: Cut.sm,
                    width: 92,
                    height: 48,
                    borderColor: null,
                    color: LS.teal,
                    onTap: canPost ? _post : null,
                    child: Center(
                      child: _posting
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: LS.bg,
                              ),
                            )
                          : const DisplayText('Post', size: 18, color: LS.bg),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            MonoLabel(
              helper,
              size: 10,
              color: _error != null ? LS.coral : LS.dim,
            ),
          ],
        ],
      ),
    );
  }
}
