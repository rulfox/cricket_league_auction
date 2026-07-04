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
    return Scaffold(
      appBar: AppBar(
        title: const Text('PLAYERS LIST'),
      ),
      body: Stack(
        children: [
          SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage("assets/images/background.jpg"),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          Center(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(
                      left: 20.0, right: 20.0, top: 30.0, bottom: 40.0),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.normal,
                        fontFamily: 'VTFRedZone',
                        color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Search Players',
                      labelStyle: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.normal,
                          fontFamily: 'VTFRedZone',
                          color: Colors.white),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                      ),
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
                const SizedBox(height: 16.0),
                Expanded(
                  child: ListView.builder(
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      Player player = _searchResults[index];
                      return GestureDetector(
                        child: ListTile(
                          title: Text(
                              "${player.getPlayerId()} - ${player.getPlayerName()}",
                              style: const TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.normal,
                                  fontFamily: 'VTFRedZone',
                                  color: Colors.white)),
                        ),
                        onTap: () => {
                          Navigator.pop(context),
                          widget.setPlayer(player)
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
