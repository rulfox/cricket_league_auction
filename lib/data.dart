import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:path/path.dart';

import 'constants.dart';
class Player {
  Player({
    this.timestamp,
    this.slNo,
    this.name,
    this.phoneNumber,
    this.currentTeam,
    this.category,
    this.photoUrl,
    this.photoFileName,
    this.battingStyle,
    this.bowlingStyle,
    this.bowlingArm,});

  Player.fromJson(dynamic json) {
    timestamp = json['timestamp'];
    slNo = json['sl_no'];
    name = json['name'];
    phoneNumber = json['phone_number'];
    currentTeam = json['current_team'];
    category = json['category'];
    photoUrl = json['photo_url'];
    photoFileName = json['photo_file_name'];
    battingStyle = json['batting_style'];
    bowlingStyle = json['bowling_style'];
    bowlingArm = json['bowling_arm'];
  }
  double? timestamp;
  int? slNo;
  String? name;
  int? phoneNumber;
  String? currentTeam;
  String? category;
  String? photoUrl;
  String? photoFileName;
  String? battingStyle;
  String? bowlingStyle;
  String? bowlingArm;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['timestamp'] = timestamp;
    map['sl_no'] = slNo;
    map['name'] = name;
    map['phone_number'] = phoneNumber;
    map['current_team'] = currentTeam;
    map['category'] = category;
    map['photo_url'] = photoUrl;
    map['photo_file_name'] = photoFileName;
    map['batting_style'] = battingStyle;
    map['bowling_style'] = bowlingStyle;
    map['bowling_arm'] = bowlingArm;
    return map;
  }

  String getPlayerPhoto(){
    return "assets/images/player/$photoFileName";
  }

  String getPlayerName(){
    return name ?? "";
  }

  String getCurrentTeam() {
    return currentTeam ?? "General County (Assumed)";
  }

  String getBattingStyle() {
    return battingStyle ?? "-";
  }

  String getBowlingStyle() {
    return bowlingStyle ?? "-";
  }

  String getBowlingArm() {
    return bowlingArm ?? "-";
  }

  String getCategoryName(){
    return category ?? "";
  }

  String getPlayerId() {
    return slNo.toString();
  }
}

Player parsePlayerFromJson(String jsonString) {
  final jsonData = jsonDecode(jsonString);
  return Player.fromJson(jsonData);
}

Future<List<Player>> getPlayersData() async {
  String playersJson = await rootBundle.loadString("lpl_players.json");
  List<Player> players = (jsonDecode(playersJson) as List)
      .map((json) => Player.fromJson(json))
      .toList();
  for (Player player in players) {
    print("ID: ${player.getPlayerId()}, Player: ${player.name}, Category: ${player.category}, URL: ${player.getPlayerPhoto()}");
  }
  return players;
}
