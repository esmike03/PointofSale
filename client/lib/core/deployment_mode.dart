enum DeploymentMode { standalone, localNetwork, hosted }

extension DeploymentModeLabel on DeploymentMode {
  String get label => switch (this) {
        DeploymentMode.standalone => 'Standalone',
        DeploymentMode.localNetwork => 'Local network',
        DeploymentMode.hosted => 'Hosted',
      };

  bool get needsServer => this != DeploymentMode.standalone;
}
