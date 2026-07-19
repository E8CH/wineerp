import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'api_client.dart';
import 'report_repository.dart';

/// 엑셀 다운로드 (FR11).
///
/// 모바일에는 사용자가 뒤져볼 "다운로드 폴더" 경험이 마땅치 않다. 이 파일의 용도는
/// **회장/오너 보고 문서 첨부**이므로, 임시 디렉터리에 저장한 뒤 곧바로 공유 시트를
/// 띄우는 것이 실제 사용 흐름과 맞는다(메일·카카오톡·드라이브).
class ExportRepository {
  ExportRepository(this._dio);

  final Dio _dio;

  /// 파일을 받아 공유 시트를 띄운다. 저장 경로를 반환한다(테스트·확인용).
  Future<String> shareReceivingXlsx(ReportPeriod period) async {
    final resp = await _dio.get<List<int>>(
      '/reports/receiving.xlsx',
      queryParameters: {'period': period.wire},
      options: Options(responseType: ResponseType.bytes),
    );

    // ⚠️ 서버 헤더의 파일명을 그대로 경로에 붙이지 않는다. 지금 서버는 안전한
    // ASCII만 만들지만, 프록시나 향후 변경이 `../`를 흘리면 임시 디렉터리 밖에 쓴다.
    final name = _safeName(_filenameFrom(resp.headers));
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(resp.data!);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: '입고 내역 (${period.label})',
      ),
    );
    return file.path;
  }

  /// 경로 구분자·상위 이동을 제거하고 파일명만 남긴다.
  String _safeName(String? raw) {
    final base = (raw ?? '')
        .replaceAll('\\', '/')
        .split('/')
        .last
        .replaceAll('..', '');
    return base.isEmpty ? 'wineerp-receiving.xlsx' : base;
  }

  /// 서버가 정한 파일명을 쓴다 — 기간이 이름에 들어 있어 보고서에 첨부했을 때
  /// 어느 기간인지 파일만 봐도 알 수 있다.
  String? _filenameFrom(Headers headers) {
    final disposition = headers.value('content-disposition');
    if (disposition == null) return null;
    final match = RegExp('filename="([^"]+)"').firstMatch(disposition);
    return match?.group(1);
  }
}

final exportRepositoryProvider = Provider<ExportRepository>(
  (ref) => ExportRepository(ref.watch(dioProvider)),
);
