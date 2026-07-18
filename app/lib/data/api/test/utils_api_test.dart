import 'package:test/test.dart';
import 'package:wineerp_api/wineerp_api.dart';


/// tests for UtilsApi
void main() {
  final instance = WineerpApi().getUtilsApi();

  group(UtilsApi, () {
    // Health
    //
    //Future<BuiltMap<String, String>> healthApiV1HealthGet() async
    test('test healthApiV1HealthGet', () async {
      // TODO
    });

  });
}
