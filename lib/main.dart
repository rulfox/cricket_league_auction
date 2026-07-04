import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models/player.dart';
import 'screens/home_card_screen.dart';
import 'services/persistence_service.dart';
import 'state/auction_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        home: const HomeCardScreen(title: 'Auction Planner'),
      ),
    );
  }
}
