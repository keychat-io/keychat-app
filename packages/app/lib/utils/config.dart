import 'package:app/utils.dart';

import 'config.default.dart' as default_config;
import 'config_dev1.dart' as config_dev1;
import 'config_dev2.dart' as config_dev2;
import 'config_dev3.dart' as config_dev3;
import 'config_prod.dart' as config_prod;

class Config {
  static final Config _singleton = Config._internal();
  factory Config() {
    return _singleton;
  }
  Config._internal();
  static String _env = 'prod';
  static get env => _env;

  init(String env) {
    _env = env;
    logger.e('🚀🚀🚀🚀🚀🚀 Env: $_env 🚀🚀🚀🚀🚀🚀');
  }

  static isProd() {
    return _env == 'prod';
  }

  static final Map _config = {
    'dev1': config_dev1.config,
    'dev2': config_dev2.config,
    'dev3': config_dev3.config,
    'prod': config_prod.config
  };

  static getEnvConfig(name) {
    return _config[_env][name] ?? default_config.config[name];
  }
}
