import 'dart:ui';

import 'package:cricket_league_auction/FullScreenImageScreen.dart';
import 'package:cricket_league_auction/data.dart';
import 'package:cricket_league_auction/players_popup.dart';
import 'package:flutter/material.dart';

List<Player> _players = [];

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _players =
      await getPlayersData();
  print("Players Length -> ${_players.length}");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
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
  Player _player = _players[0];
  bool showPlayersSearch = false;

  void _setPlayer(Player player) {
    setState(() {
      _player = player;
    });
  }

  @override
  void initState() {
    super.initState();
    //displayPlayersSequentially(); // Call the function here
  }

  void displayPlayersSequentially() async {
    for (var player in _players) {
      setState(() {
        _player = player;
      });
      await Future.delayed(const Duration(seconds: 1)); // Delay for 5 seconds
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: <Widget>[
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
          Row(children: <Widget>[
            Expanded(
                child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FullScreenImageScreen(imagePath: _player.getPlayerPhoto()),
                        ),
                      );
                    },
                  child: Stack(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          child: ImageFiltered(
                            imageFilter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
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
            Expanded(
              child: Column(children: <Widget>[
                Expanded(
                  child: Container(
                    alignment: Alignment.bottomCenter,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.only(left: 30, right: 30),
                          child: FittedBox(
                            fit: BoxFit.contain,
                            child: Text("#${_player.getPlayerId()}",
                                style: const TextStyle(
                                    fontSize: 90,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'VTFRedZone',
                                    color: Colors.white)),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 30, right: 30),
                          child: FittedBox(
                            fit: BoxFit.contain,
                            child: Text(_player.getPlayerName(),
                                style: const TextStyle(
                                    fontSize: 120,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'VTFRedZone',
                                    color: Colors.white)),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 30, right: 30),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(_player.getCurrentTeam(),
                                style: const TextStyle(
                                    fontSize: 90,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'VTFRedZone',
                                    color: Colors.white)),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 30, right: 30),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(_player.getCategoryName(),
                                style: const TextStyle(
                                    fontSize: 70,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'VTFRedZone',
                                    color: Colors.white)),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 30, right: 30),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text("${_player.getBattingStyle()} Batsman",
                                style: const TextStyle(
                                    fontSize: 50,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'VTFRedZone',
                                    color: Colors.white)),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 30, right: 30),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text("${_player.getBowlingArm()} ${_player.getBowlingStyle()} Bowler",
                                style: const TextStyle(
                                    fontSize: 50,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'VTFRedZone',
                                    color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                /*Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter, // Align to the bottom
                    child: SizedBox(
                      width: 300, // Set your desired width
                      height: 200, // Set your desired height
                      child: Image.asset(
                        "assets/images/logo_ymcl_hd.png",
                        opacity: const AlwaysStoppedAnimation(.75),
                        fit: BoxFit.cover, // or BoxFit.fill, depending on your preference
                      ),
                    ),
                  ),
                ),*/
              ]),
            ),
          ]),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            FloatingActionButton(
              onPressed: () => {
                //_setPlayer(Player(name: "Arun Raj", category: "Batsman", price: 30200, photo: "upl_logo.png")),
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
                )
              },
              tooltip: 'Search',
              child: const Icon(Icons.search),
            ),
            /*const SizedBox(width: 30),
            FloatingActionButton(
              onPressed: () => {
                //_setPlayer(Player(name: "Arun Raj", category: "Batsman", price: 30200, photo: "upl_logo.png")),
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
                )
              },
              tooltip: 'Share',
              child: const Icon(Icons.share),
            ),*/
          ],
        ),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
