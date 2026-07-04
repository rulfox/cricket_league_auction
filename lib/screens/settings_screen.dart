import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/auction_settings.dart';
import '../models/team.dart';
import '../state/auction_state.dart';
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
  final TextEditingController _addTeamController = TextEditingController();
  late AuctionMode _mode;

  @override
  void initState() {
    super.initState();
    final settings = context.read<AuctionState>().settings;
    _purseController = TextEditingController(text: settings.totalPurse.toString());
    _minBaseController = TextEditingController(text: settings.minBasePoint.toString());
    _playersPerTeamController =
        TextEditingController(text: settings.playersPerTeam.toString());
    _mode = settings.mode;
  }

  @override
  void dispose() {
    _purseController.dispose();
    _minBaseController.dispose();
    _playersPerTeamController.dispose();
    _addTeamController.dispose();
    super.dispose();
  }

  Future<void> _saveRules() async {
    final auctionState = context.read<AuctionState>();
    final purse = int.tryParse(_purseController.text);
    final minBase = int.tryParse(_minBaseController.text);
    final playersPerTeam = int.tryParse(_playersPerTeamController.text);
    if (purse == null ||
        purse <= 0 ||
        minBase == null ||
        minBase <= 0 ||
        playersPerTeam == null ||
        playersPerTeam <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Enter valid positive numbers for purse, min base point, and players per team.'),
      ));
      return;
    }
    await auctionState.updateSettings(auctionState.settings.copyWith(
      totalPurse: purse,
      minBasePoint: minBase,
      playersPerTeam: playersPerTeam,
      mode: _mode,
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
      _mode = defaults.mode;
    });
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Full reset complete.')));
  }

  @override
  Widget build(BuildContext context) {
    final teams = context.watch<AuctionState>().teams;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Teams', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
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
                  decoration: const InputDecoration(labelText: 'New team name'),
                  onSubmitted: (_) => _addTeam(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(icon: const Icon(Icons.add), onPressed: _addTeam),
            ],
          ),
          const Divider(height: 32),
          Text('Purse & Rules', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          TextField(
            controller: _purseController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Total purse per team'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _minBaseController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Minimum base point'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _playersPerTeamController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Players per team'),
          ),
          const SizedBox(height: 16),
          Text('Auction Mode', style: Theme.of(context).textTheme.titleMedium),
          RadioGroup<AuctionMode>(
            groupValue: _mode,
            onChanged: (value) => setState(() => _mode = value!),
            child: const Column(
              children: [
                RadioListTile<AuctionMode>(
                  value: AuctionMode.standard,
                  title: Text('Standard'),
                  subtitle: Text(
                      'Extra bidding is allowed (with confirmation) once a team\'s purse is exhausted.'),
                ),
                RadioListTile<AuctionMode>(
                  value: AuctionMode.strictPurse,
                  title: Text('Strict Purse Mode'),
                  subtitle: Text(
                      'Purse is a hard cap. Points are always reserved for remaining player slots; extra bidding is never allowed.'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _saveRules, child: const Text('Save Purse & Rules')),
          const Divider(height: 48),
          Text(
            'Danger Zone',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.red),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            style: OutlinedButton.styleFrom(foregroundColor: Colors.orange),
            onPressed: _clearAllBids,
            child: const Text('Clear all bids'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
            onPressed: _fullReset,
            child: const Text('Full reset (teams, settings & bids)'),
          ),
        ],
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              onSubmitted: widget.onRename,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: widget.onDelete,
          ),
        ],
      ),
    );
  }
}
