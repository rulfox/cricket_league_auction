import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:path/path.dart';

import 'constants.dart';
class Player {
  Player({
    this.id,
    this.name,
    this.department,
    this.currentOffice,
    this.permanentAddress,
    this.category,
    this.photo,
    this.battingStyle,
    this.bowlingStyle,
    this.bowlingArm,
    this.paymentStatus,
    this.team,});

  Player.fromJson(dynamic json) {
    id = json['id'];
    name = json['name'];
    department = json['department'];
    currentOffice = json['current_office'];
    permanentAddress = json['permanent_address'];
    category = json['category'];
    photo = json['photo'];
    battingStyle = json['batting_style'];
    bowlingStyle = json['bowling_style'];
    bowlingArm = json['bowling_arm'];
    paymentStatus = json['payment_status'];
    team = json['team'];
  }
  int? id;
  String? name;
  String? department;
  String? currentOffice;
  String? permanentAddress;
  String? category;
  String? photo;
  String? battingStyle;
  String? bowlingStyle;
  String? bowlingArm;
  String? paymentStatus;
  String? team;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['id'] = id;
    map['name'] = name;
    map['department'] = department;
    map['current_office'] = currentOffice;
    map['permanent_address'] = permanentAddress;
    map['category'] = category;
    map['photo'] = photo;
    map['batting_style'] = battingStyle;
    map['bowling_style'] = bowlingStyle;
    map['bowling_arm'] = bowlingArm;
    map['payment_status'] = paymentStatus;
    map['team'] = team;
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