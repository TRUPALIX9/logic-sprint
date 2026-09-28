import 'dart:math';

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

/// Picks the display name shown on the Global Top 10, plus a 4-digit code
/// ("NEON_FOX#0420"). Many players can share a name; only name + code is
/// unique, and the server says when one is taken. "Find a free code" asks
/// the server for an unused one.
class NameSheet extends StatefulWidget {
  const NameSheet({super.key});

  @override
  State<NameSheet> createState() => _NameSheetState();
}

class _NameSheetState extends State<NameSheet> {
  late final TextEditingController _name;
  late final TextEditingController _tag;
  late final String? _current;
  late final int? _currentTag;
  bool _saving = false;
  bool _finding = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final leaderboard = context.read<Leaderboard>();
    _current = leaderboard.savedName;
    _currentTag = leaderboard.savedTag;
    _name = TextEditingController(text: _current ?? '');
    _tag = TextEditingController(
      text: Leaderboard.formatTag(_currentTag ?? Random().nextInt(10000)),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _tag.dispose();
    super.dispose();
  }

  int? get _tagValue => _tag.text.length == 4 ? int.tryParse(_tag.text) : null;

  bool get _canSave {
    final name = _name.text.trim();
    final tag = _tagValue;
    return !_saving &&
        name.isNotEmpty &&
        tag != null &&
        (name != _current || tag != _currentTag);
  }

  Future<void> _findFreeTag() async {
    final name = _name.text.trim();
    if (name.isEmpty || _finding) {
      return;
    }
    setState(() {
      _finding = true;
      _error = null;
    });
    final tag = await context.read<Leaderboard>().suggestTag(name);
    if (mounted) {
      setState(() {
        _finding = false;
        _tag.text = Leaderboard.formatTag(tag);
      });
    }
  }

  Future<void> _save() async {
    final leaderboard = context.read<Leaderboard>();
    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await leaderboard.claimName(_name.text, _tagValue!);
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
                      ? 'Shown on the Global Top 10 as NAME#CODE. Pick any '
                            'name and a free 4-digit code.'
                      : 'Shown on the Global Top 10 as NAME#CODE.',
                  style: LSText.body(15, color: LS.muted),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: ChamferBox(
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
                                style: LSText.mono(
                                  17,
                                  color: LS.text,
                                  spacing: 0.04,
                                ),
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
                    ),
                    const SizedBox(width: 8),
                    ChamferBox(
                      cut: Cut.sm,
                      width: 104,
                      height: 56,
                      color: LS.surface2,
                      borderColor: error != null
                          ? LS.coral
                          : LS.teal.withValues(alpha: 0.5),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          Text(
                            '#',
                            style: LSText.mono(17, color: LS.dim, spacing: 0),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: TextField(
                              controller: _tag,
                              enabled: !_saving,
                              keyboardType: TextInputType.number,
                              style: LSText.mono(
                                17,
                                color: LS.teal,
                                spacing: 0.08,
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(4),
                              ],
                              textInputAction: TextInputAction.done,
                              onChanged: (_) => setState(() => _error = null),
                              onSubmitted: (_) => _canSave ? _save() : null,
                              decoration: InputDecoration.collapsed(
                                hintText: '0000',
                                hintStyle: LSText.mono(
                                  17,
                                  color: LS.dim,
                                  spacing: 0.08,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: CardAction(
                    label: _finding ? 'Finding…' : 'Find a free code',
                    onTap: _findFreeTag,
                  ),
                ),
                const SizedBox(height: 8),
                MonoLabel(
                  error ??
                      'Letters, numbers, spaces, _ and - · '
                          'up to ${AppConfig.maxPlayerNameLength} · '
                          'any 4-digit code',
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
