import 'dart:convert';

import 'package:flutter/services.dart';

class Player {
  Player({
    this.id,
    this.name,
    this.department,
    this.phoneNumber,
    this.photo,
    this.category
  });

  Player.fromJson(dynamic json) {
    id = json['id'];
    name = json['name'];
    department = json['department'];
    phoneNumber = json['phone_number'];
    photo = json['photo_file_name'];
    category = json['category'];
  }
  String? id;
  String? name;
  String? department;
  String? phoneNumber;
  String? photo;
  String? category;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['id'] = id;
    map['name'] = name;
    map['department'] = department;
    map['phone_number'] = phoneNumber;
    map['photo_file_name'] = photo;
    map['category'] = category;
    return map;
  }

  String getPlayerPhoto(){
    return "assets/images/player/$photo";
  }

  String getPlayerName(){
    return name ?? "";
  }

  String getCurrentTeam() {
    return department ?? "General County (Assumed)";
  }

  String getCategoryName(){
    return category ?? "";
  }

  String getPlayerId() {
    return id.toString();
  }
}

Player parsePlayerFromJson(String jsonString) {
  final jsonData = jsonDecode(jsonString);
  return Player.fromJson(jsonData);
}

Future<List<Player>> getPlayersData() async {
  String playersJson = await rootBundle.loadString("players.json");
  List<Player> players = (jsonDecode(playersJson) as List)
      .map((json) => Player.fromJson(json))
      .toList();
  print("Players Data: ${players.length}");
  for (Player player in players) {
    print("ID: ${player.getPlayerId()}, Player: ${player.name}, Category: ${player.category}, URL: ${player.getPlayerPhoto()}");
  }
  return players;
}