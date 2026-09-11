import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';
import '../ui/kit.dart';

/// Renders the bundled privacy policy (the same markdown that is hosted for
/// the store listing): `##` headings, `_italic_` date line, paragraphs.
class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});

  static Route<void> route() =>
      MaterialPageRoute<void>(builder: (_) => const PrivacyScreen());

  static const asset = 'assets/brand/docs/privacy_policy.md';

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  late final Future<String> _policy = rootBundle.loadString(
    PrivacyScreen.asset,
  );

  List<Widget> _blocks(String markdown) {
    final blocks = <Widget>[];
    for (final raw in markdown.split(RegExp(r'\n\s*\n'))) {
      final text = raw.trim().replaceAll('**', '');
      if (text.isEmpty || text.startsWith('# ')) {
        continue;
      }
      if (text.startsWith('## ')) {
        blocks.add(
          Padding(
            padding: const EdgeInsets.only(top: 18, bottom: 8),
            child: DisplayText(text.substring(3), size: 18, color: LS.teal),
          ),
        );
      } else if (text.startsWith('_') && text.endsWith('_')) {
        blocks.add(MonoLabel(text.substring(1, text.length - 1)));
      } else {
        blocks.add(
          Text(
            text.replaceAll('\n', ' '),
            style: LSText.body(14, color: LS.muted, height: 1.6),
          ),
        );
      }
    }
    return blocks;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const LSTopBar(title: 'Privacy policy'),
            Expanded(
              child: FutureBuilder<String>(
                future: _policy,
                builder: (context, snapshot) => snapshot.hasData
                    ? ListView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                        children: _blocks(snapshot.data!),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
