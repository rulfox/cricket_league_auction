import 'dart:ui';
import 'package:cricket_league_auction/FullScreenImageScreen.dart';
import 'package:cricket_league_auction/data.dart';
import 'package:cricket_league_auction/players_popup.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

List<Player> _players = [];

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _players = await getPlayersData();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Auction Planner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Auction Planner'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late Player _player;

  @override
  void initState() {
    super.initState();
    _player = _players[0];
  }

  void _setPlayer(Player player) {
    setState(() {
      _player = player;
    });
  }

  void _navigatePlayer(int direction) {
    int currentIndex = _players.indexOf(_player);
    int nextIndex = currentIndex + direction;

    if (nextIndex >= 0 && nextIndex < _players.length) {
      _setPlayer(_players[nextIndex]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
            _navigatePlayer(1),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
            _navigatePlayer(-1),
        const SingleActivator(LogicalKeyboardKey.space): () =>
            Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PlayersPopup(
              players: _players,
              setPlayer: (Player player) {
                _setPlayer(player);
              },
            ),
          ),
        ),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: Stack(
            children: <Widget>[
              Row(children: <Widget>[
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage(
                            "assets/images/background.png"),
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                      ),
                    ),
                    child: Column(children: <Widget>[
                      Expanded(
                        child: Center(
                          child: SizedBox(
                            width: 200,
                            height: 200,
                            child: Image.asset(
                              "assets/images/msl_logo.png",
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(
                            left: 30, right: 30, bottom: 40),
                        child: Column(
                          children: <Widget>[
                            FittedBox(
                              fit: BoxFit.contain,
                              child: Text("#${_player.getPlayerId()}",
                                  style: const TextStyle(
                                      fontSize: 100,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'VTFRedZone',
                                      color: Colors.white)),
                            ),
                            const SizedBox(height: 20),
                            FittedBox(
                              fit: BoxFit.contain,
                              child: Text(_player.getPlayerName(),
                                  style: const TextStyle(
                                      fontSize: 110,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'VTFRedZone',
                                      color: Colors.white)),
                            ),
                            const SizedBox(height: 16),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(_player.getTeam(),
                                  style: const TextStyle(
                                      fontSize: 80,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'VTFRedZone',
                                      color: Colors.white)),
                            ),
                            const SizedBox(height: 12),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(_player.getCategory(),
                                  style: const TextStyle(
                                      fontSize: 60,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'VTFRedZone',
                                      color: Colors.white)),
                            ),
                            const SizedBox(height: 12),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                "${_player.getBattingStyle()} Batsman  |  ${_player.getBowlingArm()} Arm ${_player.getBowlingStyle()} Bowler",
                                style: const TextStyle(
                                    fontSize: 50,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'VTFRedZone',
                                    color: Colors.white),
                              ),
                            ),
                            const SizedBox(height: 12),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(_player.getPhoneNumber(),
                                  style: const TextStyle(
                                      fontSize: 50,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'VTFRedZone',
                                      color: Colors.white)),
                            ),
                          ],
                        ),
                      ),
                    ]),
                  ),
                ),
                Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FullScreenImageScreen(
                                imagePath: _player.getPlayerPhoto()),
                          ),
                        );
                      },
                      child: Stack(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              child: ImageFiltered(
                                imageFilter:
                                    ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                                child: Image.asset(
                                  _player.getPlayerPhoto(),
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                ),
                              ),
                            ),
                          ),
                          Image.asset(
                            _player.getPlayerPhoto(),
                            fit: BoxFit.fitHeight,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        ],
                      ),
                    )),
              ]),
            ],
          ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.endDocked,
          floatingActionButton: Padding(
            padding: const EdgeInsets.all(16.0),
            child: FloatingActionButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PlayersPopup(
                    players: _players,
                    setPlayer: (Player player) {
                      _setPlayer(player);
                    },
                  ),
                ),
              ),
              tooltip: 'Search',
              child: const Icon(Icons.search),
            ),
          ),
        ),
      ),
    );
  }
}
