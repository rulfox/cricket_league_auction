import 'package:flutter/material.dart';

import '../models/player.dart';

class PlayersPopup extends StatefulWidget {
  final Function(Player) setPlayer;
  final List<Player> players;

  const PlayersPopup(
      {Key? key, required this.players, required this.setPlayer})
      : super(key: key);

  @override
  State<PlayersPopup> createState() => _PlayersPopupState();
}

class _PlayersPopupState extends State<PlayersPopup> {
  final List<Player> _players = [];
  final TextEditingController _searchController = TextEditingController();
  List<Player> _searchResults = [];

  // Create a FocusNode for the TextField
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (_searchController.text.isEmpty) {
        setState(() {
          _searchResults = _players;
        });
      } else {
        List<Player> searchResults = [];
        for (Player player in _players) {
          if (player.getPlayerName().toLowerCase().contains(_searchController.text.toLowerCase()) ||
              _searchController.text.toLowerCase() == player.getPlayerId().toString()) {
            searchResults.add(player);
          }
        }
        setState(() {
          _searchResults = searchResults;
        });
      }
    });

    // Focus on TextField after the screen is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(FocusNode()); // Remove previous focus
      FocusScope.of(context).requestFocus(_searchFocusNode); // Set focus
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose(); // Dispose the FocusNode
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _players.clear();
    _players.addAll(widget.players);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Search Players')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: InputDecoration(
                hintText: 'Search by name or number',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
              ),
              onSubmitted: (text) {
                if (_searchResults.isNotEmpty) {
                  // Select the first suggestion
                  widget.setPlayer(_searchResults[0]);
                  Navigator.pop(context);
                }
              },
            ),
          ),
          Expanded(
            child: _searchResults.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person_search_outlined,
                            size: 48, color: colorScheme.onSurfaceVariant),
                        const SizedBox(height: 8),
                        Text(
                          'No players found',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: _searchResults.length,
                    separatorBuilder: (_, __) => const Divider(indent: 72),
                    itemBuilder: (context, index) {
                      final player = _searchResults[index];
                      return ListTile(
                        leading: CircleAvatar(
                          radius: 22,
                          backgroundImage: AssetImage(player.getPlayerPhoto()),
                          onBackgroundImageError: (_, __) {},
                        ),
                        title: Text(player.getPlayerName()),
                        subtitle: Text('#${player.getPlayerId()} · ${player.getCategory()}'),
                        trailing: Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
                        onTap: () {
                          Navigator.pop(context);
                          widget.setPlayer(player);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
