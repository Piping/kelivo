class CodexRemoteHost {
  final String serverName;
  final String codexHome;
  final String cwd;
  final String modelProviderId;
  final String version;

  const CodexRemoteHost({
    required this.serverName,
    required this.codexHome,
    required this.cwd,
    required this.modelProviderId,
    required this.version,
  });

  factory CodexRemoteHost.fromJson(Map<String, dynamic> json) {
    return CodexRemoteHost(
      serverName: json['serverName'] as String? ?? '',
      codexHome: json['codexHome'] as String? ?? '',
      cwd: json['cwd'] as String? ?? '',
      modelProviderId: json['modelProviderId'] as String? ?? '',
      version: json['version'] as String? ?? '',
    );
  }
}
