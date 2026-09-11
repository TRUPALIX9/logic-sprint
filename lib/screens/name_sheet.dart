import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/config.dart';
import '../core/theme.dart';
import '../services/leaderboard.dart';
import '../ui/chamfer.dart';
import '../ui/kit.dart';

/// Opens the name picker. Completes with true once a name is saved.
Future<bool> showNameSheet(BuildContext context) async =>
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const NameSheet(),
    ) ??
    false;

/// Picks the display name shown on the Global Top 10. Names are unique
/// (ignoring case); the server says when one is taken.
class NameSheet extends StatefulWidget {
  const NameSheet({super.key});

  @override
  State<NameSheet> createState() => _NameSheetState();
}

class _NameSheetState extends State<NameSheet> {
  late final TextEditingController _name;
  late final String? _current;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _current = context.read<Leaderboard>().savedName;
    _name = TextEditingController(text: _current ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _canSave {
    final name = _name.text.trim();
    return !_saving && name.isNotEmpty && name != _current;
  }

  Future<void> _save() async {
    final leaderboard = context.read<Leaderboard>();
    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await leaderboard.claimName(_name.text);
    if (!mounted) {
      return;
    }
    if (error == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _saving = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          shape: chamfer(Cut.lg, border: LS.line),
          color: LS.surface,
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: Container(width: 40, height: 4, color: LS.line)),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: DisplayText(
                        _current == null ? 'Choose your name' : 'Change name',
                        size: 28,
                        maxLines: 1,
                      ),
                    ),
                    LSIconButton(
                      icon: Icons.close_rounded,
                      tooltip: 'Close',
                      color: LS.muted,
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _current == null
                      ? 'Shown on the Global Top 10. You only do this once.'
                      : 'Shown on the Global Top 10 next to your bests.',
                  style: LSText.body(15, color: LS.muted),
                ),
                const SizedBox(height: 18),
                ChamferBox(
                  cut: Cut.sm,
                  height: 56,
                  color: LS.surface2,
                  borderColor: error != null
                      ? LS.coral
                      : LS.teal.withValues(alpha: 0.5),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
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
                          autofocus: true,
                          enabled: !_saving,
                          autocorrect: false,
                          enableSuggestions: false,
                          style: LSText.mono(17, color: LS.text, spacing: 0.04),
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(
                              AppConfig.maxPlayerNameLength,
                            ),
                          ],
                          textInputAction: TextInputAction.done,
                          onChanged: (_) => setState(() => _error = null),
                          onSubmitted: (_) => _canSave ? _save() : null,
                          decoration: InputDecoration.collapsed(
                            hintText: 'Display name',
                            hintStyle: LSText.mono(
                              17,
                              color: LS.dim,
                              spacing: 0.04,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                MonoLabel(
                  error ??
                      'Letters, numbers, spaces, _ and - · '
                          'up to ${AppConfig.maxPlayerNameLength}',
                  size: 10,
                  color: error != null ? LS.coral : LS.dim,
                ),
                const SizedBox(height: 18),
                PrimaryButton(
                  label: _saving ? 'Saving…' : 'Save name',
                  onPressed: _canSave ? _save : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
