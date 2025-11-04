import 'package:keychat/utils.dart';

import 'package:keychat/utils/config.default.dart' as default_config;
import 'package:keychat/utils/config_dev1.dart' as config_dev1;
import 'package:keychat/utils/config_dev2.dart' as config_dev2;
import 'package:keychat/utils/config_dev3.dart' as config_dev3;
import 'package:keychat/utils/config_prod.dart' as config_prod;

class Config {
  // Avoid self instance
  Config._();
  static Config? _instance;
  static Config get instance => _instance ??= Config._();
  static String _env = 'prod';
  static String get env => _env;

  void init(String env) {
    _env = env;
    logger.e('🚀🚀🚀🚀🚀🚀 Env: $_env 🚀🚀🚀🚀🚀🚀');
  }

  static bool isProd() {
    return _env == 'prod';
  }

  static final Map _config = {
    'dev1': config_dev1.config,
    'dev2': config_dev2.config,
    'dev3': config_dev3.config,
    'prod': config_prod.config,
  };

  static dynamic getEnvConfig(String name) {
    return _config[_env][name] ?? default_config.config[name];
  }
}
