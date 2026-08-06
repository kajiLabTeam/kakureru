/// RTDBのSDKが返す `Map<dynamic, dynamic>` を、`json_serializable` が
/// 生成する `fromJson` が前提とする `Map<String, dynamic>` へ再帰的に変換する。
///
/// RTDBはネストしたMap/Listも全て `dynamic` キーで返してくるため、
/// この変換なしでは生成コードの `as Map<String, dynamic>` キャストが失敗する。
Map<String, dynamic> rtdbMapToJson(Map<dynamic, dynamic> raw) {
  return raw.map((key, value) => MapEntry(key.toString(), _convert(value)));
}

dynamic _convert(dynamic value) {
  if (value is Map) return rtdbMapToJson(value);
  if (value is List) return value.map(_convert).toList();
  return value;
}
