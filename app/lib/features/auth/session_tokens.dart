/// The token pair a signed-in device holds (US-016).
///
/// Deliberately a plain value type with no persistence of its own: where it is
/// stored is [SecureTokenStore]'s decision, and that separation is what keeps
/// the tokens out of `shared_preferences` by construction rather than by
/// remembering. See `secure_token_store.dart`.
library;

/// A short-lived access token and the refresh token that renews it.
class SessionTokens {
  const SessionTokens({
    required this.accessToken,
    required this.accessTokenExpiresAt,
    required this.refreshToken,
    required this.sessionId,
  });

  /// Sent on every authenticated request. Fifteen minutes, server-side.
  final String accessToken;

  /// When the server will stop accepting [accessToken].
  ///
  /// Held so the client can renew *before* a request fails rather than after.
  /// Reacting to a 401 works, but it costs the user a visible stall on the one
  /// request that happened to cross the boundary.
  final DateTime accessTokenExpiresAt;

  /// Exchanged for a new pair. Single-use: the server rotates it away on every
  /// refresh and treats a second presentation as theft.
  final String refreshToken;

  /// Identifies this device's session in the "signed-in devices" list.
  final String sessionId;

  /// Whether [accessToken] should be renewed before being used at [now].
  ///
  /// The skew matters. Renewing exactly at expiry races the request against the
  /// server's clock and loses often enough to matter on a slow connection, so
  /// the token is treated as spent slightly early.
  bool needsRefresh(DateTime now, {Duration skew = refreshSkew}) =>
      !now.isBefore(accessTokenExpiresAt.subtract(skew));

  /// Thirty seconds — comfortably more than a request takes, far less than the
  /// fifteen-minute lifetime it is shaving.
  static const Duration refreshSkew = Duration(seconds: 30);

  Map<String, String> toJson() => {
        'accessToken': accessToken,
        'accessTokenExpiresAt': accessTokenExpiresAt.toIso8601String(),
        'refreshToken': refreshToken,
        'sessionId': sessionId,
      };

  /// Returns null for anything malformed rather than throwing.
  ///
  /// The stored blob can be garbage for reasons that are nobody's fault — a
  /// half-finished write, a restored backup, a downgrade to an older build. The
  /// correct response to all of them is to treat the device as signed out, not
  /// to crash on launch.
  static SessionTokens? fromJson(Map<String, dynamic> json) {
    final accessToken = json['accessToken'];
    final expiresAt = json['accessTokenExpiresAt'];
    final refreshToken = json['refreshToken'];
    final sessionId = json['sessionId'];
    if (accessToken is! String ||
        expiresAt is! String ||
        refreshToken is! String ||
        sessionId is! String) {
      return null;
    }
    final parsed = DateTime.tryParse(expiresAt);
    if (parsed == null) return null;
    return SessionTokens(
      accessToken: accessToken,
      accessTokenExpiresAt: parsed,
      refreshToken: refreshToken,
      sessionId: sessionId,
    );
  }

  /// Never prints the tokens. A `toString` that leaks a credential into a crash
  /// report or a debug console is the whole reason this override exists.
  @override
  String toString() => 'SessionTokens(sessionId: $sessionId, '
      'expiresAt: ${accessTokenExpiresAt.toIso8601String()})';
}
