import 'dart:ui';
import 'package:archive/archive.dart';
import 'package:cricket_league_auction/FullScreenImageScreen.dart';
import 'package:cricket_league_auction/data.dart';
import 'package:cricket_league_auction/players_popup.dart';
import 'package:cricket_league_auction/web_download.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

  final GlobalKey _captureKey = GlobalKey();
  bool _isCapturing = false;
  bool _packaging = false;
  int _captureProgress = 0;

  // Resolution multiplier for exported cards. 2.0 stays crisp while cutting
  // pixel count (and PNG-encode time) ~55% vs 3.0. Raise for sharper output.
  static const double _capturePixelRatio = 2.0;

  @override
  void initState() {
    super.initState();
    _player = _players[0];
  }

  Future<void> _captureAllPlayers() async {
    setState(() {
      _isCapturing = true;
      _packaging = false;
      _captureProgress = 0;
    });

    final archive = Archive();
    for (int i = 0; i < _players.length; i++) {
      final player = _players[i];
      if (!mounted) return;

      // Decode the photo into the image cache FIRST, while the previous card is
      // still on screen. This way the frame we capture paints the photo on its
      // first build instead of a blank placeholder. Tolerate undecodable assets
      // (e.g. .HEIC on web) so one bad image can't abort the whole export.
      try {
        await precacheImage(AssetImage(player.getPlayerPhoto()), context);
      } catch (_) {}
      if (!mounted) return;

      // Switch the displayed card AND the counter together, so every painted
      // frame shows the image with its matching number (last image -> 132/132).
      setState(() {
        _player = player;
        _captureProgress = i + 1;
      });
      // Wait for the frame that paints this (now-cached) photo, then force one
      // more guaranteed frame to cover a late image-stream microtask.
      await WidgetsBinding.instance.endOfFrame;
      WidgetsBinding.instance.scheduleFrame();
      await WidgetsBinding.instance.endOfFrame;

      final boundary =
          _captureKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: _capturePixelRatio);
      final bytes =
          (await image.toByteData(format: ImageByteFormat.png))!
              .buffer
              .asUint8List();
      image.dispose();

      // PNG is already compressed; store it uncompressed to skip a costly,
      // near-useless second DEFLATE pass over hundreds of MB.
      final file =
          ArchiveFile('${player.getPlayerId()}.png', bytes.length, bytes)
            ..compress = false;
      archive.addFile(file);
    }

    // Show the final count + a "Packaging" state and let it paint BEFORE the
    // synchronous zip encode blocks the isolate (otherwise the counter looks
    // stuck at the last value while the ZIP is built).
    if (!mounted) return;
    setState(() => _packaging = true);
    await WidgetsBinding.instance.endOfFrame;

    final zip = ZipEncoder().encode(archive)!;
    downloadBytes(zip, 'players.zip');

    if (!mounted) return;
    setState(() {
      _isCapturing = false;
      _packaging = false;
    });
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

  Widget _buildStyledText(String text, {double fontSize = 48}) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          fontFamily: 'VTFRedZone',
          color: Colors.white,
          shadows: [
            Shadow(
              offset: const Offset(2, 2),
              blurRadius: 4,
              color: Colors.black.withValues(alpha: 0.7),
            ),
            Shadow(
              offset: const Offset(-1, -1),
              blurRadius: 3,
              color: Colors.black.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
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
              RepaintBoundary(
                key: _captureKey,
                child: Row(children: <Widget>[
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
                    child: Column(
                      children: <Widget>[
                        Expanded(
                          flex: 4,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Center(
                              child: Image.asset(
                                "assets/images/msl_logo.png",
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 6,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 16),
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  _buildStyledText(
                                    "#${_player.getPlayerId()}",
                                    fontSize: 70,
                                  ),
                                  const SizedBox(height: 10),
                                  _buildStyledText(
                                    _player.getPlayerName(),
                                    fontSize: 85,
                                  ),
                                  const SizedBox(height: 10),
                                  _buildStyledText(
                                    _player.getTeam(),
                                    fontSize: 60,
                                  ),
                                  const SizedBox(height: 8),
                                  _buildStyledText(
                                    _player.getCategory(),
                                    fontSize: 48,
                                  ),
                                  const SizedBox(height: 8),
                                  _buildStyledText(
                                    "${_player.getBattingStyle()} Batsman | ${_player.getBowlingArm()} ${_player.getBowlingStyle()} Bowler",
                                    fontSize: 38,
                                  ),
                                  const SizedBox(height: 8),
                                  _buildStyledText(
                                    _player.getPhoneNumber(),
                                    fontSize: 36,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
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
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
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
              ),
              if (_isCapturing)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.6),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(
                              color: Colors.white),
                          const SizedBox(height: 24),
                          Text(
                            _packaging
                                ? "Packaging ZIP…"
                                : "Exporting $_captureProgress / ${_players.length}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.endDocked,
          floatingActionButton: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (kIsWeb) ...[
                  FloatingActionButton(
                    heroTag: 'capture',
                    onPressed: _isCapturing ? null : _captureAllPlayers,
                    tooltip: 'Export all as ZIP',
                    child: const Icon(Icons.photo_library),
                  ),
                  const SizedBox(width: 16),
                ],
                FloatingActionButton(
                  heroTag: 'search',
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
