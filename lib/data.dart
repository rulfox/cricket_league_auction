import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:path/path.dart';

import 'constants.dart';
class Player {
  Player({
    this.slNo,
    this.name,
    this.phoneNumber,
    this.team,
    this.category,
    this.battingStyle,
    this.bowlingStyle,
    this.address,
    this.photoFileName,
  });

  Player.fromJson(dynamic json) {
    slNo = json['sl_no'];
    name = json['name'];
    phoneNumber = json['phone_number']?.toString();
    team = json['team'];
    category = json['category'];
    battingStyle = json['batting_style'];
    bowlingStyle = json['bowling_style'];
    address = json['address'];
    photoFileName = json['photo_file_name'];
  }

  int? slNo;
  String? name;
  String? phoneNumber;
  String? team;
  String? category;
  String? battingStyle;
  String? bowlingStyle;
  String? address;
  String? photoFileName;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['sl_no'] = slNo;
    map['Name'] = name;
    map['Phone Number'] = phoneNumber;
    map['team'] = team;
    map['category'] = category;
    map['batting_style'] = battingStyle;
    map['bowling_style'] = bowlingStyle;
    map['address'] = address;
    map['photo_file_name'] = photoFileName;
    return map;
  }

  String getPlayerPhoto() {
    return "assets/images/player/$photoFileName";
  }

  String getPlayerName() {
    return name ?? "";
  }

  String getPhoneNumber() {
    return phoneNumber ?? "";
  }

  String getTeam() {
    return team ?? "";
  }

  String getBattingStyle() {
    return battingStyle ?? "-";
  }

  String getBowlingStyle() {
    return bowlingStyle ?? "-";
  }

  String getAddress() {
    return address ?? "";
  }

  String getPlayerId() {
    return slNo?.toString() ?? "";
  }

  String getCategory() {
    return category ?? "";
  }
}


Player parsePlayerFromJson(String jsonString) {
  final jsonData = jsonDecode(jsonString);
  return Player.fromJson(jsonData);
}

// dart
Future<List<Player>> getPlayersData() async {
  String playersJson = await rootBundle.loadString("players.json");
  List<Player> players = (jsonDecode(playersJson) as List)
      .map((json) => Player.fromJson(json))
      /*.where((p) =>
  p.photoFileName != null &&
      p.photoFileName!.trim().isNotEmpty &&
      p.photoFileName!.toLowerCase() != 'null')*/
      .toList();
  for (Player player in players) {
    print("Player: ${player.name}, Category: ${player.category}, URL: ${player.getPlayerPhoto()}");
  }
  return players;
}

