import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logic_sprint/models/game_model.dart';
import 'package:logic_sprint/models/second_life_config.dart';
import 'package:logic_sprint/widgets/game_over_continue_overlay.dart';

void main() {
  testWidgets('first fail shows Watch Ad for Second Life and End Game', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GameOverContinueOverlay(
          score: 42,
          bestScore: 100,
          config: SecondLifeConfig.forGame(GameType.quickMath),
          secondLifeAvailable: true,
          adReady: true,
          isShowingAd: false,
          onWatchAd: () {},
          onEndGame: () {},
          onPlayAgain: () {},
          onBackToGames: () {},
        ),
      ),
    );

    expect(find.text(SecondLifeConfig.watchAdButtonLabel), findsOneWidget);
    expect(find.text(SecondLifeConfig.endGameLabel), findsOneWidget);
    expect(find.text(SecondLifeConfig.playAgainLabel), findsNothing);
  });

  testWidgets('after second life used shows Play Again not watch ad', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GameOverContinueOverlay(
          score: 42,
          bestScore: 100,
          config: SecondLifeConfig.forGame(GameType.quickMath),
          secondLifeAvailable: false,
          adReady: false,
          isShowingAd: false,
          onEndGame: () {},
          onPlayAgain: () {},
          onBackToGames: () {},
        ),
      ),
    );

    expect(find.text(SecondLifeConfig.watchAdButtonLabel), findsNothing);
    expect(find.text(SecondLifeConfig.playAgainLabel), findsOneWidget);
    expect(find.text(SecondLifeConfig.gameOverTitle), findsOneWidget);
  });
}
