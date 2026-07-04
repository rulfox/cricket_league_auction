import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/auction_settings.dart';
import '../models/team.dart';
import '../state/auction_state.dart';
import '../theme.dart';
import '../widgets/confirm_export_dialog.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _purseController;
  late final TextEditingController _minBaseController;
  late final TextEditingController _playersPerTeamController;
  late final TextEditingController _jackpotDurationController;
  final TextEditingController _addTeamController = TextEditingController();
  final FocusNode _addTeamFocusNode = FocusNode();
  late AuctionMode _mode;

  @override
  void initState() {
    super.initState();
    final settings = context.read<AuctionState>().settings;
    _purseController = TextEditingController(text: settings.totalPurse.toString());
    _minBaseController = TextEditingController(text: settings.minBasePoint.toString());
    _playersPerTeamController =
        TextEditingController(text: settings.playersPerTeam.toString());
    _jackpotDurationController =
        TextEditingController(text: settings.jackpotDurationSeconds.toString());
    _mode = settings.mode;
  }

  @override
  void dispose() {
    _purseController.dispose();
    _minBaseController.dispose();
    _playersPerTeamController.dispose();
    _jackpotDurationController.dispose();
    _addTeamController.dispose();
    _addTeamFocusNode.dispose();
    super.dispose();
  }

  Future<void> _saveRules() async {
    final auctionState = context.read<AuctionState>();
    final purse = int.tryParse(_purseController.text);
    final minBase = int.tryParse(_minBaseController.text);
    final playersPerTeam = int.tryParse(_playersPerTeamController.text);
    final jackpotDuration = int.tryParse(_jackpotDurationController.text);
    if (purse == null ||
        purse <= 0 ||
        minBase == null ||
        minBase <= 0 ||
        playersPerTeam == null ||
        playersPerTeam <= 0 ||
        jackpotDuration == null ||
        jackpotDuration <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Enter valid positive numbers for purse, min base point, players per team, and jackpot duration.'),
      ));
      return;
    }
    await auctionState.updateSettings(auctionState.settings.copyWith(
      totalPurse: purse,
      minBasePoint: minBase,
      playersPerTeam: playersPerTeam,
      mode: _mode,
      jackpotDurationSeconds: jackpotDuration,
    ));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Settings saved.')));
  }

  Future<void> _addTeam() async {
    final name = _addTeamController.text.trim();
    if (name.isEmpty) return;
    await context.read<AuctionState>().addTeam(name);
    _addTeamController.clear();
    if (!mounted) return;
    // Re-request focus after the rebuild the new team triggers, so the
    // auctioneer can keep typing team names one after another without
    // manually re-clicking the field each time.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _addTeamFocusNode.requestFocus();
    });
  }

  Future<void> _renameTeam(Team team, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty || trimmed == team.name) return;
    await context.read<AuctionState>().renameTeam(team.id, trimmed);
  }

  Future<void> _removeTeam(Team team) async {
    final confirmed = await confirmExport(
      context,
      title: 'Delete Team',
      message: 'Delete team "${team.name}"?',
      confirmLabel: 'Delete',
    );
    if (!confirmed || !mounted) return;
    final result = await context.read<AuctionState>().removeTeam(team.id);
    if (!mounted || result.wasRemoved) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          'Cannot delete "${team.name}": ${result.blockedByCount} player(s) already sold to this team.'),
    ));
  }

  Future<void> _clearAllBids() async {
    final confirmed = await confirmExport(
      context,
      title: 'Clear All Bids',
      message:
          'Clear all bids? Teams and settings are kept, but every player becomes Available again. This cannot be undone.',
      confirmLabel: 'Clear Bids',
    );
    if (!confirmed || !mounted) return;
    await context.read<AuctionState>().resetRecordsOnly();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('All bids cleared.')));
  }

  Future<void> _fullReset() async {
    final controller = TextEditingController();
    final typed = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Full Reset'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'This permanently deletes ALL teams, settings, and bids. Type CONFIRM to proceed.'),
            const SizedBox(height: 12),
            TextField(controller: controller, autofocus: true),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Reset Everything'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (typed?.trim().toUpperCase() != 'CONFIRM' || !mounted) return;

    await context.read<AuctionState>().resetEverything();
    if (!mounted) return;
    setState(() {
      const defaults = AuctionSettings.defaults;
      _purseController.text = defaults.totalPurse.toString();
      _minBaseController.text = defaults.minBasePoint.toString();
      _playersPerTeamController.text = defaults.playersPerTeam.toString();
      _jackpotDurationController.text = defaults.jackpotDurationSeconds.toString();
      _mode = defaults.mode;
    });
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Full reset complete.')));
  }

  @override
  Widget build(BuildContext context) {
    final teams = context.watch<AuctionState>().teams;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionCard(
            icon: Icons.groups,
            title: 'Teams',
            children: [
              for (final team in teams)
                _TeamTile(
                  key: ValueKey(team.id),
                  team: team,
                  onRename: (name) => _renameTeam(team, name),
                  onDelete: () => _removeTeam(team),
                ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _addTeamController,
                      focusNode: _addTeamFocusNode,
                      decoration: const InputDecoration(hintText: 'Add a new team…'),
                      onSubmitted: (_) => _addTeam(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(icon: const Icon(Icons.add), onPressed: _addTeam),
                ],
              ),
            ],
          ),
          _SectionCard(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Purse & Rules',
            children: [
              TextField(
                controller: _purseController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Total purse per team',
                  prefixIcon: Icon(Icons.savings_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _minBaseController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Minimum base point',
                  prefixIcon: Icon(Icons.trending_up),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _playersPerTeamController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Players per team',
                  prefixIcon: Icon(Icons.groups_2_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _jackpotDurationController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Jackpot shuffle duration (seconds)',
                  prefixIcon: Icon(Icons.casino_outlined),
                ),
              ),
              const SizedBox(height: 16),
              Text('Auction Mode', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              RadioGroup<AuctionMode>(
                groupValue: _mode,
                onChanged: (value) => setState(() => _mode = value!),
                child: Column(
                  children: [
                    RadioListTile<AuctionMode>(
                      value: AuctionMode.standard,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      title: const Text('Standard'),
                      subtitle: const Text(
                          'Extra bidding is allowed (with confirmation) once a team\'s purse is exhausted.'),
                    ),
                    RadioListTile<AuctionMode>(
                      value: AuctionMode.strictPurse,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      title: const Text('Strict Purse Mode'),
                      subtitle: const Text(
                          'Purse is a hard cap. Points are always reserved for remaining player slots; extra bidding is never allowed.'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saveRules,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save Purse & Rules'),
                ),
              ),
            ],
          ),
          Card(
            color: colorScheme.errorContainer.withValues(alpha: 0.25),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: kStatusDanger),
                      const SizedBox(width: 8),
                      Text(
                        'Danger Zone',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(color: kStatusDanger),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kStatusWarning,
                        side: const BorderSide(color: kStatusWarning),
                      ),
                      onPressed: _clearAllBids,
                      icon: const Icon(Icons.restart_alt),
                      label: const Text('Clear all bids'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kStatusDanger,
                        side: const BorderSide(color: kStatusDanger),
                      ),
                      onPressed: _fullReset,
                      icon: const Icon(Icons.delete_forever_outlined),
                      label: const Text('Full reset (teams, settings & bids)'),
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

/// Consistent icon + title header, divider, then section content — the one
/// pattern shared by every Settings section.
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.icon, required this.title, required this.children});

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _TeamTile extends StatefulWidget {
  const _TeamTile({super.key, required this.team, required this.onRename, required this.onDelete});

  final Team team;
  final ValueChanged<String> onRename;
  final VoidCallback onDelete;

  @override
  State<_TeamTile> createState() => _TeamTileState();
}

class _TeamTileState extends State<_TeamTile> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.team.name);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.only(left: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              onSubmitted: widget.onRename,
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
            onPressed: widget.onDelete,
          ),
        ],
      ),
    );
  }
}
