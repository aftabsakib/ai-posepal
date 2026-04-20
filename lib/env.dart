import 'package:envied/envied.dart';

part 'env.g.dart';

@Envied(path: '.env')
abstract class Env {
  @EnviedField(varName: 'CLAUDE_API_KEY', obfuscate: true)
  static final String claudeApiKey = _Env.claudeApiKey;
}
