import 'dart:convert';
import 'package:flutter/services.dart';

class Player {
  Player({
    this.slNo,
    this.name,
    this.phoneNumber,
    this.team,
    this.category,
    this.battingStyle,
    this.bowlingStyle,
    this.bowlingArm,
    this.photoFileName,
  });

  Player.fromJson(dynamic json) {
    slNo = int.tryParse(json['sl_no']?.toString() ?? '');
    name = json['name'];
    phoneNumber = json['phone']?.toString();
    team = json['team'];
    category = json['category'];
    battingStyle = json['batting_style'];
    bowlingStyle = json['bowling_style'];
    bowlingArm = json['bowling_arm'];
    photoFileName = json['photo'];
  }

  int? slNo;
  String? name;
  String? phoneNumber;
  String? team;
  String? category;
  String? battingStyle;
  String? bowlingStyle;
  String? bowlingArm;
  String? photoFileName;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['sl_no'] = slNo;
    map['name'] = name;
    map['phone'] = phoneNumber;
    map['team'] = team;
    map['category'] = category;
    map['batting_style'] = battingStyle;
    map['bowling_style'] = bowlingStyle;
    map['bowling_arm'] = bowlingArm;
    map['photo'] = photoFileName;
    return map;
  }

  String getPlayerPhoto() => "assets/images/player/$photoFileName";
  String getPlayerId() => slNo?.toString() ?? "";
  String getPlayerName() => name ?? "";
  String getPhoneNumber() => phoneNumber ?? "";
  String getTeam() => team ?? "";
  String getCategory() => category ?? "";
  String getBattingStyle() => battingStyle ?? "-";
  String getBowlingStyle() => bowlingStyle ?? "-";
  String getBowlingArm() => bowlingArm ?? "-";
}

Player parsePlayerFromJson(String jsonString) {
  final jsonData = jsonDecode(jsonString);
  return Player.fromJson(jsonData);
}

Future<List<Player>> getPlayersData() async {
  String playersJson = await rootBundle.loadString("assets/players.json");
  List<Player> players = ((jsonDecode(playersJson)['Players Only']) as List)
      .map((json) => Player.fromJson(json))
      .toList();
  return players;
}
