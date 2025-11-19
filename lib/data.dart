import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:path/path.dart';

import 'constants.dart';
class Player {
  Player({
    this.slNo,
    this.name,
    this.category,
    this.photoFileName,
    this.arm});

  Player.fromJson(dynamic json) {
    slNo = json['sl_no'];
    name = json['name'];
    category = json['category'];
    photoFileName = json['photo_file_name'];
    arm = json['arm'];
  }
  int? slNo;
  String? name;
  String? category;
  String? photoFileName;
  String? arm;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['sl_no'] = slNo;
    map['name'] = name;
    map['category'] = category;
    map['photo_file_name'] = photoFileName;
    map['arm'] = arm;
    return map;
  }

  String getPlayerPhoto(){
    return "assets/images/player/$photoFileName";
  }

  String getPlayerName(){
    return name ?? "";
  }

  String getArm() {
    return arm ?? "-";
  }

  String getPlayerId(){
    return slNo.toString() ?? "";
  }

  String getCategory(){
    return category ?? "";
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
  for (Player player in players) {
    print("Player: ${player.name}, Category: ${player.category}, URL: ${player.getPlayerPhoto()}");
  }
  return players;
}
