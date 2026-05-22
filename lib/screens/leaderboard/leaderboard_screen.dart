import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/leaderboard_score_model.dart';
import '../../services/leaderboard_service.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/leaderboard_tile.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  LeaderboardGameFilter _gameFilter = LeaderboardGameFilter.all;
  LeaderboardDifficultyFilter _difficultyFilter =
      LeaderboardDifficultyFilter.all;

  bool _loading = true;
  List<LeaderboardScoreModel> _allScores = [];
  String? _errorMessage;
  String? _infoMessage;
  DateTime? _lastUpdated;
  bool _fromCache = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInitial());
  }

  Future<void> _loadInitial() async {
    final service = context.read<LeaderboardService>();
    setState(() => _loading = true);
    final result = await service.loadLeaderboard();
    if (!mounted) {
      return;
    }
    _applyResult(result);
  }

  Future<void> _refresh() async {
    final service = context.read<LeaderboardService>();
    setState(() => _loading = true);
    final result = await service.loadLeaderboard(forceRefresh: true);
    if (!mounted) {
      return;
    }
    _applyResult(result);
  }

  void _applyResult(LeaderboardLoadResult result) {
    setState(() {
      _loading = false;
      _allScores = result.scores;
      _errorMessage = result.errorMessage;
      _infoMessage = result.infoMessage;
      _lastUpdated = result.lastUpdated;
      _fromCache = result.fromCache;
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = LeaderboardService.applyFilters(
      _allScores,
      gameFilter: _gameFilter,
      difficultyFilter: _difficultyFilter,
    );

    final lastUpdatedLabel = _lastUpdated == null
        ? 'Not loaded yet'
        : 'Last updated ${_formatTimestamp(_lastUpdated!)}${_fromCache ? ' (cached)' : ''}';

    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Global Leaderboard',
        subtitle: 'Top 100 Scores',
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final stackFilters = constraints.maxWidth < 400;
                if (stackFilters) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _gameFilterDropdown(),
                      const SizedBox(height: 10),
                      _difficultyFilterDropdown(),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: _gameFilterDropdown()),
                    const SizedBox(width: 12),
                    Expanded(child: _difficultyFilterDropdown()),
                  ],
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    lastUpdatedLabel,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton.icon(
                  onPressed: _loading ? null : _refresh,
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  label: const Text('Refresh'),
                ),
              ],
            ),
          ),
          if (_infoMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                _infoMessage!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
            ),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Text(
                _errorMessage!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          const SizedBox(height: 8),
          Expanded(child: _buildBody(filtered)),
        ],
      ),
    );
  }

  Widget _buildBody(List<LeaderboardScoreModel> filtered) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (filtered.isEmpty) {
      if (_errorMessage != null && _allScores.isEmpty) {
        return const EmptyState(
          icon: Icons.cloud_off_rounded,
          title: 'Leaderboard unavailable',
          message: 'Online leaderboard is temporarily unavailable.',
        );
      }
      return const EmptyState(
        icon: Icons.leaderboard_rounded,
        title: 'No scores yet',
        message:
            'No scores match these filters. Try All games and All difficulties.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      itemCount: filtered.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        return LeaderboardTile(rank: index + 1, score: filtered[index]);
      },
    );
  }

  Widget _gameFilterDropdown() {
    return DropdownButtonFormField<LeaderboardGameFilter>(
      isExpanded: true,
      initialValue: _gameFilter,
      decoration: const InputDecoration(
        labelText: 'Game',
        border: OutlineInputBorder(),
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      items: const [
        DropdownMenuItem(
          value: LeaderboardGameFilter.all,
          child: Text('All Games', overflow: TextOverflow.ellipsis),
        ),
        DropdownMenuItem(
          value: LeaderboardGameFilter.quickMath,
          child: Text('Quick Math', overflow: TextOverflow.ellipsis),
        ),
        DropdownMenuItem(
          value: LeaderboardGameFilter.colorSequence,
          child: Text('Color Sequence', overflow: TextOverflow.ellipsis),
        ),
        DropdownMenuItem(
          value: LeaderboardGameFilter.trueFalse,
          child: Text('True or False', overflow: TextOverflow.ellipsis),
        ),
      ],
      onChanged: (value) {
        if (value == null) {
          return;
        }
        setState(() => _gameFilter = value);
      },
    );
  }

  Widget _difficultyFilterDropdown() {
    return DropdownButtonFormField<LeaderboardDifficultyFilter>(
      isExpanded: true,
      initialValue: _difficultyFilter,
      decoration: const InputDecoration(
        labelText: 'Difficulty',
        border: OutlineInputBorder(),
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      items: const [
        DropdownMenuItem(
          value: LeaderboardDifficultyFilter.all,
          child: Text('All Difficulties', overflow: TextOverflow.ellipsis),
        ),
        DropdownMenuItem(
          value: LeaderboardDifficultyFilter.easy,
          child: Text('Easy', overflow: TextOverflow.ellipsis),
        ),
        DropdownMenuItem(
          value: LeaderboardDifficultyFilter.medium,
          child: Text('Medium', overflow: TextOverflow.ellipsis),
        ),
        DropdownMenuItem(
          value: LeaderboardDifficultyFilter.hard,
          child: Text('Hard', overflow: TextOverflow.ellipsis),
        ),
      ],
      onChanged: (value) {
        if (value == null) {
          return;
        }
        setState(() => _difficultyFilter = value);
      },
    );
  }

  String _formatTimestamp(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final suffix = value.hour >= 12 ? 'PM' : 'AM';
    return '${value.month}/${value.day}/${value.year} $hour:$minute $suffix';
  }
}
