/// User model - mirrors backend /auth/login and /profile response.
class AppUser {
  final int id;
  final String fullName;
  final String username;
  final String email;
  final String? avatarUrl;
  final int playerLevel;
  final int experience;
  final String? countryCode;
  final String? bio;
  final int totalMatches;
  final int totalWins;
  final int totalLosses;
  final int totalCaptures;
  final int coins;
  final int gems;
  final bool isOnline;

  AppUser({
    required this.id,
    required this.fullName,
    required this.username,
    required this.email,
    this.avatarUrl,
    this.playerLevel = 1,
    this.experience = 0,
    this.countryCode,
    this.bio,
    this.totalMatches = 0,
    this.totalWins = 0,
    this.totalLosses = 0,
    this.totalCaptures = 0,
    this.coins = 500,
    this.gems = 10,
    this.isOnline = false,
  });

  double get winRate =>
      totalMatches > 0 ? (totalWins / totalMatches) * 100 : 0.0;

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
    id: (j['id'] as num).toInt(),
    fullName: j['full_name'] as String? ?? '',
    username: j['username'] as String? ?? '',
    email: j['email'] as String? ?? '',
    avatarUrl: j['avatar_url'] as String?,
    playerLevel: (j['player_level'] as num?)?.toInt() ?? 1,
    experience: (j['experience'] as num?)?.toInt() ?? 0,
    countryCode: j['country_code'] as String?,
    bio: j['bio'] as String?,
    totalMatches: (j['total_matches'] as num?)?.toInt() ?? 0,
    totalWins: (j['total_wins'] as num?)?.toInt() ?? 0,
    totalLosses: (j['total_losses'] as num?)?.toInt() ?? 0,
    totalCaptures: (j['total_captures'] as num?)?.toInt() ?? 0,
    coins: (j['coins'] as num?)?.toInt() ?? 500,
    gems: (j['gems'] as num?)?.toInt() ?? 10,
    isOnline: (j['is_online'] as num?)?.toInt() == 1,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'full_name': fullName,
    'username': username,
    'email': email,
    'avatar_url': avatarUrl,
    'player_level': playerLevel,
    'experience': experience,
    'country_code': countryCode,
    'bio': bio,
    'total_matches': totalMatches,
    'total_wins': totalWins,
    'total_losses': totalLosses,
    'total_captures': totalCaptures,
    'coins': coins,
    'gems': gems,
    'is_online': isOnline,
  };

  AppUser copyWith({
    String? fullName,
    String? username,
    String? avatarUrl,
    int? coins,
    int? gems,
    int? playerLevel,
    int? experience,
    int? totalMatches,
    int? totalWins,
    int? totalLosses,
    int? totalCaptures,
  }) =>
      AppUser(
        id: id,
        fullName: fullName ?? this.fullName,
        username: username ?? this.username,
        email: email,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        playerLevel: playerLevel ?? this.playerLevel,
        experience: experience ?? this.experience,
        countryCode: countryCode,
        bio: bio,
        totalMatches: totalMatches ?? this.totalMatches,
        totalWins: totalWins ?? this.totalWins,
        totalLosses: totalLosses ?? this.totalLosses,
        totalCaptures: totalCaptures ?? this.totalCaptures,
        coins: coins ?? this.coins,
        gems: gems ?? this.gems,
        isOnline: isOnline,
      );
}
