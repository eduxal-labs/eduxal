/// M-Pesa Daraja API configuration model.
///
/// Stores the fields a school needs to integrate with Safaricom's M-Pesa
/// Daraja API (specifically STK Push / Lipa Na M-Pesa Online).
///
/// ## Field sensitivity
///
/// | Field            | Sensitive | Display  |
/// |------------------|-----------|----------|
/// | consumerKey      | Yes       | •••••    |
/// | consumerSecret   | Yes       | •••••    |
/// | passkey          | Yes       | •••••    |
/// | shortCode        | No        | Visible  |
/// | accountReference  | No        | Visible  |
/// | callbackUrl      | No        | Visible  |
/// | environment      | No        | Visible  |
/// | enabled          | No        | Visible  |
class MpesaConfig {
  const MpesaConfig({
    this.consumerKey = '',
    this.consumerSecret = '',
    this.shortCode = '',
    this.passkey = '',
    this.accountReference = '',
    this.callbackUrl = '',
    this.environment = MpesaEnvironment.sandbox,
    this.enabled = false,
  });

  // ---------------------------------------------------------------------------
  // Sensitive fields — displayed as '•••••' in the UI
  // ---------------------------------------------------------------------------

  /// Daraja app consumer key (from the Safaricom developer portal).
  final String consumerKey;

  /// Daraja app consumer secret (from the Safaricom developer portal).
  final String consumerSecret;

  /// Lipa Na M-Pesa Online passkey (provided by Safaricom for STK Push).
  final String passkey;

  // ---------------------------------------------------------------------------
  // Non-sensitive fields — displayed in plain text
  // ---------------------------------------------------------------------------

  /// Business short code — Paybill or Till number.
  final String shortCode;

  /// Account reference format string used in STK Push requests.
  /// Typically the school name or an invoice prefix (e.g. "EduXal-INV").
  final String accountReference;

  /// The URL Safaricom will POST STK Push results to.
  final String callbackUrl;

  /// Whether this config targets the sandbox or production environment.
  final MpesaEnvironment environment;

  /// Master switch — when `false` the integration is disabled even if
  /// all fields are filled in.
  final bool enabled;

  // ---------------------------------------------------------------------------
  // Computed
  // ---------------------------------------------------------------------------

  /// Returns `true` when all required fields are non-empty.
  ///
  /// A config can be "configured" but not [enabled] — the user explicitly
  /// toggled it off. [isConfigured] only checks data completeness.
  bool get isConfigured =>
      consumerKey.isNotEmpty &&
      consumerSecret.isNotEmpty &&
      shortCode.isNotEmpty &&
      passkey.isNotEmpty &&
      callbackUrl.isNotEmpty;

  // ---------------------------------------------------------------------------
  // Serialization
  // ---------------------------------------------------------------------------

  factory MpesaConfig.fromJson(Map<String, dynamic> json) {
    return MpesaConfig(
      consumerKey: json['consumer_key'] as String? ?? '',
      consumerSecret: json['consumer_secret'] as String? ?? '',
      shortCode: json['short_code'] as String? ?? '',
      passkey: json['passkey'] as String? ?? '',
      accountReference: json['account_reference'] as String? ?? '',
      callbackUrl: json['callback_url'] as String? ?? '',
      environment: _envFromString(json['environment'] as String?),
      enabled: json['enabled'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'consumer_key': consumerKey,
      'consumer_secret': consumerSecret,
      'short_code': shortCode,
      'passkey': passkey,
      'account_reference': accountReference,
      'callback_url': callbackUrl,
      'environment': environment.name,
      'enabled': enabled,
    };
  }

  // ---------------------------------------------------------------------------
  // Copyable
  // ---------------------------------------------------------------------------

  MpesaConfig copyWith({
    String? consumerKey,
    String? consumerSecret,
    String? shortCode,
    String? passkey,
    String? accountReference,
    String? callbackUrl,
    MpesaEnvironment? environment,
    bool? enabled,
  }) {
    return MpesaConfig(
      consumerKey: consumerKey ?? this.consumerKey,
      consumerSecret: consumerSecret ?? this.consumerSecret,
      shortCode: shortCode ?? this.shortCode,
      passkey: passkey ?? this.passkey,
      accountReference: accountReference ?? this.accountReference,
      callbackUrl: callbackUrl ?? this.callbackUrl,
      environment: environment ?? this.environment,
      enabled: enabled ?? this.enabled,
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static MpesaEnvironment _envFromString(String? value) {
    if (value == 'production') return MpesaEnvironment.production;
    return MpesaEnvironment.sandbox;
  }

  /// Masks a sensitive value for display: shows first 4 chars then bullets.
  /// Returns '•••••' if the value is too short or empty.
  static String mask(String value) {
    if (value.length <= 4) return '•••••';
    return '${value.substring(0, 4)}${'•' * 5}';
  }

  @override
  String toString() =>
      'MpesaConfig(shortCode: $shortCode, '
      'environment: ${environment.name}, '
      'enabled: $enabled, '
      'configured: $isConfigured)';
}

/// M-Pesa API environment.
enum MpesaEnvironment {
  /// Safaricom sandbox — for testing.
  sandbox,

  /// Safaricom production — live payments.
  production;

  /// Human-readable label for UI display.
  String get label => switch (this) {
    sandbox => 'Sandbox',
    production => 'Production',
  };
}
