import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models/player.dart';
import 'screens/home_card_screen.dart';
import 'services/persistence_service.dart';
import 'state/auction_state.dart';
import 'theme.dart';
import 'widgets/secret_jackpot_gesture_detector.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Defense in depth: raise the cache ceiling above Flutter's ~100MB default.
  // The real fix for oversized decoded photos is decoding at the right size
  // in the first place (see TeamRosterCard.photoProviderFor), but a bigger
  // budget is a cheap extra cushion for future larger rosters.
  PaintingBinding.instance.imageCache.maximumSizeBytes = 200 << 20;
  final players = await getPlayersData();
  final auctionState =
      AuctionState(players: players, persistence: AuctionPersistenceService());
  await auctionState.load();
  runApp(MyApp(auctionState: auctionState));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.auctionState});

  final AuctionState auctionState;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: auctionState,
      child: MaterialApp(
        title: 'Auction Planner',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const HomeCardScreen(title: 'Auction Planner'),
        builder: (context, child) => SecretJackpotGestureDetector(child: child!),
      ),
    );
  }
}
