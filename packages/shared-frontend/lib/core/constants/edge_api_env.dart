import 'api_runtime_config.dart';
import '../network/api_client.dart';

/// Edge (veya başka) Flutter girişinde `.env` yüklendikten sonra çağrın; [ApiClient] önbelleğini sıfırlar.
void applyFrontendEnvMap(Map<String, String> map) {
  ApiRuntimeConfig.applyFromMap(map);
  ApiClient.clearForReconfiguration();
}
