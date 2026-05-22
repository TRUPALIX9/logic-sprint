import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/game_model.dart';
import '../../models/leaderboard_entry.dart';
import '../../services/leaderboard_service.dart';
import '../../widgets/app_gradient_background.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/leaderboard_tile.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  GameType _selectedGame = GameType.quickMath;
  bool _loading = true;
  List<LeaderboardEntry> _entries = [];
  String? _errorMessage;
  String? _lastFetchedDate;
  bool _fromCache = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInitial());
  }

  Future<void> _loadInitial() async {
    final service = context.read<LeaderboardService>();
    await service.syncPendingSubmissions();
    await _load(gameType: _selectedGame);
  }

  Future<void> _load({required GameType gameType, bool force = false}) async {
    final service = context.read<LeaderboardService>();
    setState(() => _loading = true);
    final result = await service.loadLeaderboard(
      gameType: gameType,
      forceRefresh: force,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _loading = false;
      _entries = result.entries;
      _errorMessage = result.errorMessage;
      _lastFetchedDate = result.lastFetchedDate;
      _fromCache = result.fromCache;
    });
  }

  Future<void> _onGameChanged(GameType? game) async {
    if (game == null) {
      return;
    }
    setState(() => _selectedGame = game);
    await _load(gameType: game);
  }

  String get _cacheStatusLabel {
    if (_lastFetchedDate == null) {
      return 'Not loaded yet';
    }
    final today = _formatTodayKey();
    if (_lastFetchedDate == today) {
      return 'Updated today${_fromCache ? ' (cached)' : ''}';
    }
    return 'Last updated $_lastFetchedDate';
  }

  String _formatTodayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppGradientBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                      color: AppGradientBackground.textPrimary,
                    ),
                    Expanded(
                      child: Text(
                        'All-Time Leaderboard',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppGradientBackground.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _loading
                          ? null
                          : () => _load(gameType: _selectedGame, force: true),
                      icon: const Icon(Icons.refresh_rounded),
                      color: AppGradientBackground.textPrimary,
                      tooltip: 'Refresh',
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: DropdownButtonFormField<GameType>(
                  isExpanded: true,
                  initialValue: _selectedGame,
                  dropdownColor: const Color(0xFF1A2F5C),
                  style: const TextStyle(
                    color: AppGradientBackground.textPrimary,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Game',
                    labelStyle: TextStyle(
                      color: AppGradientBackground.textSecondary,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: AppGradientBackground.cyanAccent.withValues(
                          alpha: 0.4,
                        ),
                      ),
                    ),
                  ),
                  items: [
                    for (final game in homeLauncherGames)
                      DropdownMenuItem(
                        value: game.type,
                        child: Text(game.title),
                      ),
                  ],
                  onChanged: _onGameChanged,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Text(
                  _cacheStatusLabel,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppGradientBackground.textSecondary,
                  ),
                ),
              ),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    _errorMessage!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppGradientBackground.orangeAccent,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Expanded(child: _buildList()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_entries.isEmpty) {
      return EmptyState(
        icon: Icons.leaderboard_rounded,
        title: _errorMessage == null
            ? 'No scores yet'
            : 'Leaderboard unavailable',
        message:
            _errorMessage ??
            'Be the first to set an all-time best for this game.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      itemCount: _entries.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        return LeaderboardTile(rank: index + 1, entry: _entries[index]);
      },
    );
  }
}
