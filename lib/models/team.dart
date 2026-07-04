class Team {
  Team({required this.id, required this.name});

  /// Stable identifier, generated once at creation and never derived from
  /// [name] — this is what makes renaming a team after sales exist safe,
  /// since [PlayerAuctionRecord.teamId] always points at this id.
  final String id;
  String name;

  Team copyWith({String? name}) => Team(id: id, name: name ?? this.name);

  factory Team.fromJson(Map<String, dynamic> json) => Team(
        id: json['id'] as String,
        name: json['name'] as String,
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}
