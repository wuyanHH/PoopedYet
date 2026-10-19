import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'webdav_config.dart';

/// 远端备份文件条目。
class WebDavRemoteFile {
  const WebDavRemoteFile({
    required this.name,
    required this.href,
    required this.sizeBytes,
    this.modifiedAt,
  });

  final String name;
  final String href;
  final int sizeBytes;
  final DateTime? modifiedAt;

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// 连接测试结果。
class WebDavTestResult {
  const WebDavTestResult({
    required this.success,
    required this.message,
    this.statusCode,
  });

  final bool success;
  final String message;
  final int? statusCode;
}

/// 纯 Dart 原生实现的轻量安全 WebDAV 客户端。
class WebDavClient {
  WebDavClient({required this.config});

  final WebDavConfig config;

  static const Duration _connectTimeout = Duration(seconds: 12);
  static const Duration _responseTimeout = Duration(seconds: 25);

  HttpClient _createHttpClient() {
    final client = HttpClient();
    client.connectionTimeout = _connectTimeout;
    if (config.allowSelfSignedCert) {
      client.badCertificateCallback = (cert, host, port) => true;
    }
    return client;
  }

  String _getAuthHeader() {
    final bytes = utf8.encode('${config.username}:${config.password}');
    return 'Basic ${base64Encode(bytes)}';
  }

  /// 规范化基础 URL，去除末尾斜线。
  String get _cleanBaseUrl {
    var u = config.serverUrl.trim();
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    return u;
  }

  /// 规范化目录路径，内部构造 URL 时以 `/` 开头并以 `/` 结尾。
  String get _cleanDirPath {
    final folder = config.cleanFolderName;
    return '/$folder/';
  }

  Uri _buildUri(String subPath) {
    var cleanSub = subPath.trim();
    if (cleanSub.startsWith('/')) cleanSub = cleanSub.substring(1);
    return Uri.parse('$_cleanBaseUrl$_cleanDirPath$cleanSub');
  }

  Uri _buildDirUri([String? customPath]) {
    final p = customPath ?? _cleanDirPath;
    var norm = p.trim();
    if (!norm.startsWith('/')) norm = '/$norm';
    if (!norm.endsWith('/')) norm = '$norm/';
    return Uri.parse('$_cleanBaseUrl$norm');
  }

  // ==========================================================================
  //  连接测试
  // ==========================================================================

  /// 测试与 WebDAV 服务器的连通性与账号密码有效性。
  Future<WebDavTestResult> testConnection() async {
    final client = _createHttpClient();
    try {
      final uri = _buildDirUri();
      final request = await client.openUrl('PROPFIND', uri).timeout(_connectTimeout);
      request.headers.set(HttpHeaders.authorizationHeader, _getAuthHeader());
      request.headers.set('Depth', '0');
      request.headers.set(HttpHeaders.userAgentHeader, 'PoopedYet/0.1.2');

      final response = await request.close().timeout(_responseTimeout);
      final status = response.statusCode;
      await response.drain<void>();

      if (status == 200 || status == 207) {
        return const WebDavTestResult(
          success: true,
          message: '连接成功！服务器与认证均正常',
          statusCode: 200,
        );
      } else if (status == 401 || status == 403) {
        return WebDavTestResult(
          success: false,
          message: '认证失败（HTTP $status）：用户名或授权密码错误',
          statusCode: status,
        );
      } else if (status == 404) {
        // 目标目录不存在，尝试向根目录探测
        return await _testFallbackRoot(client);
      } else {
        return WebDavTestResult(
          success: false,
          message: '服务器响应状态异常（HTTP $status）',
          statusCode: status,
        );
      }
    } on SocketException catch (e) {
      return WebDavTestResult(
        success: false,
        message: '网络连接失败：请检查服务器地址是否正确、网络是否通畅 (${e.message})',
      );
    } on TimeoutException {
      return const WebDavTestResult(
        success: false,
        message: '连接超时：服务器未能及时响应，请检查端口与防火墙',
      );
    } on HandshakeException catch (e) {
      return WebDavTestResult(
        success: false,
        message: 'SSL/TLS 安全握手失败：如果是自签名证书，请开启「允许自签名证书」(${e.message})',
      );
    } catch (e) {
      return WebDavTestResult(
        success: false,
        message: '连接异常：$e',
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<WebDavTestResult> _testFallbackRoot(HttpClient client) async {
    try {
      final rootUri = Uri.parse(_cleanBaseUrl);
      final req = await client.openUrl('PROPFIND', rootUri).timeout(_connectTimeout);
      req.headers.set(HttpHeaders.authorizationHeader, _getAuthHeader());
      req.headers.set('Depth', '0');
      final resp = await req.close().timeout(_responseTimeout);
      final s = resp.statusCode;
      await resp.drain<void>();
      if (s == 200 || s == 207) {
        return const WebDavTestResult(
          success: true,
          message: '连接成功！目标目录不存在，同步时将自动创建',
          statusCode: 200,
        );
      }
      return WebDavTestResult(
        success: false,
        message: '目标路径未找到（HTTP 404），且根目录返回 HTTP $s',
        statusCode: s,
      );
    } catch (e) {
      return WebDavTestResult(
        success: false,
        message: '目标路径不存在（HTTP 404）：$e',
        statusCode: 404,
      );
    }
  }

  // ==========================================================================
  //  目录创建与检测
  // ==========================================================================

  /// 确保远端备份目录存在，若不存在则逐级创建（MKCOL）。
  Future<void> ensureRemoteDirectory() async {
    final client = _createHttpClient();
    try {
      final segments = _cleanDirPath
          .split('/')
          .where((s) => s.trim().isNotEmpty)
          .toList();

      var currentPath = '';
      for (final segment in segments) {
        currentPath += '/$segment';
        final dirUri = _buildDirUri(currentPath);

        // 先 PROPFIND 检测
        final checkReq = await client.openUrl('PROPFIND', dirUri);
        checkReq.headers.set(HttpHeaders.authorizationHeader, _getAuthHeader());
        checkReq.headers.set('Depth', '0');
        final checkResp = await checkReq.close();
        final status = checkResp.statusCode;
        await checkResp.drain<void>();

        if (status == 404) {
          // 不存在则 MKCOL 创建
          final mkReq = await client.openUrl('MKCOL', dirUri);
          mkReq.headers.set(HttpHeaders.authorizationHeader, _getAuthHeader());
          final mkResp = await mkReq.close();
          await mkResp.drain<void>();
        }
      }
    } finally {
      client.close(force: true);
    }
  }

  // ==========================================================================
  //  上传备份
  // ==========================================================================

  /// 上传文件到 WebDAV 远端目录。
  Future<void> uploadFile({
    required String fileName,
    required String content,
  }) async {
    await ensureRemoteDirectory();

    final client = _createHttpClient();
    try {
      final uri = _buildUri(fileName);
      final request = await client.putUrl(uri).timeout(_connectTimeout);
      request.headers.set(HttpHeaders.authorizationHeader, _getAuthHeader());
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json; charset=utf-8');
      request.headers.set(HttpHeaders.userAgentHeader, 'PoopedYet/0.1.2');

      final bytes = utf8.encode(content);
      request.contentLength = bytes.length;
      request.add(bytes);

      final response = await request.close().timeout(_responseTimeout);
      final status = response.statusCode;
      await response.drain<void>();

      if (status != 200 && status != 201 && status != 204) {
        throw HttpException('上传失败：HTTP $status');
      }
    } finally {
      client.close(force: true);
    }
  }

  // ==========================================================================
  //  下载备份
  // ==========================================================================

  /// 从 WebDAV 远端下载指定文件文本。
  Future<String> downloadFile({required String fileName}) async {
    final client = _createHttpClient();
    try {
      final uri = _buildUri(fileName);
      final request = await client.getUrl(uri).timeout(_connectTimeout);
      request.headers.set(HttpHeaders.authorizationHeader, _getAuthHeader());
      request.headers.set(HttpHeaders.userAgentHeader, 'PoopedYet/0.1.2');

      final response = await request.close().timeout(_responseTimeout);
      if (response.statusCode != 200) {
        throw HttpException('下载失败：HTTP ${response.statusCode}');
      }

      final content = await response.transform(utf8.decoder).join();
      return content;
    } finally {
      client.close(force: true);
    }
  }

  /// 下载文件；**文件不存在时返回 null，而不是抛异常**。
  ///
  /// 同步流程必须能把这两件事分清楚：
  ///
  /// - 「云端还没有这份文件」= 第一次同步的正常开局，接着上传即可；
  /// - 「网络不通 / 密码错了 / 服务器 500」= 必须报错中止。
  ///
  /// 如果这里也一律抛异常、调用方统一 catch 成 null，第二种情况就会被
  /// 静默当成"云端是空的"，然后拿本地数据把云端**覆盖**掉 ——
  /// 那是要用户丢数据的事故，不是"同步失败重试一下"那么轻。
  Future<String?> downloadFileIfExists({required String fileName}) async {
    final client = _createHttpClient();
    try {
      final uri = _buildUri(fileName);
      final request = await client.getUrl(uri).timeout(_connectTimeout);
      request.headers.set(HttpHeaders.authorizationHeader, _getAuthHeader());
      request.headers.set(HttpHeaders.userAgentHeader, 'PoopedYet/0.1.2');

      final response = await request.close().timeout(_responseTimeout);

      if (response.statusCode == 404) {
        await response.drain<void>();
        return null;
      }
      if (response.statusCode != 200) {
        await response.drain<void>();
        throw HttpException('下载失败：HTTP ${response.statusCode}');
      }

      return await response.transform(utf8.decoder).join();
    } finally {
      client.close(force: true);
    }
  }

  // ==========================================================================
  //  列出远端备份文件
  // ==========================================================================

  /// 获取远端目录中的所有备份文件列表。
  Future<List<WebDavRemoteFile>> listRemoteBackups() async {
    final client = _createHttpClient();
    try {
      final uri = _buildDirUri();
      final request = await client.openUrl('PROPFIND', uri).timeout(_connectTimeout);
      request.headers.set(HttpHeaders.authorizationHeader, _getAuthHeader());
      request.headers.set('Depth', '1');
      request.headers.set(HttpHeaders.userAgentHeader, 'PoopedYet/0.1.2');

      final response = await request.close().timeout(_responseTimeout);
      if (response.statusCode != 207 && response.statusCode != 200) {
        return [];
      }

      final xmlBody = await response.transform(utf8.decoder).join();
      return _parsePropfindXml(xmlBody);
    } catch (_) {
      return [];
    } finally {
      client.close(force: true);
    }
  }

  /// 纯正则解析 WebDAV PROPFIND 返回的标准 XML 报文。
  List<WebDavRemoteFile> _parsePropfindXml(String xml) {
    final results = <WebDavRemoteFile>[];

    // 匹配每一个 <response> 块
    final responseRegex = RegExp(
      r'<(?:[a-zA-Z0-9_-]+:)?response\b[^>]*>(.*?)</(?:[a-zA-Z0-9_-]+:)?response>',
      caseSensitive: false,
      dotAll: true,
    );

    final hrefRegex = RegExp(
      r'<(?:[a-zA-Z0-9_-]+:)?href\b[^>]*>(.*?)</(?:[a-zA-Z0-9_-]+:)?href>',
      caseSensitive: false,
    );

    final lengthRegex = RegExp(
      r'<(?:[a-zA-Z0-9_-]+:)?getcontentlength\b[^>]*>(.*?)</(?:[a-zA-Z0-9_-]+:)?getcontentlength>',
      caseSensitive: false,
    );

    final modifiedRegex = RegExp(
      r'<(?:[a-zA-Z0-9_-]+:)?getlastmodified\b[^>]*>(.*?)</(?:[a-zA-Z0-9_-]+:)?getlastmodified>',
      caseSensitive: false,
    );

    final collectionRegex = RegExp(
      r'<(?:[a-zA-Z0-9_-]+:)?collection\b',
      caseSensitive: false,
    );

    final matches = responseRegex.allMatches(xml);

    for (final match in matches) {
      final block = match.group(1) ?? '';
      final hrefMatch = hrefRegex.firstMatch(block);
      if (hrefMatch == null) continue;

      var href = hrefMatch.group(1)?.trim() ?? '';
      try {
        href = Uri.decodeFull(href);
      } catch (_) {}

      // 如果是目录，跳过
      if (collectionRegex.hasMatch(block) || href.endsWith('/')) {
        continue;
      }

      // 提取文件名
      final name = href.split('/').where((s) => s.isNotEmpty).lastOrNull ?? '';
      if (!name.endsWith('.json')) continue;

      final lenMatch = lengthRegex.firstMatch(block);
      final size = int.tryParse(lenMatch?.group(1)?.trim() ?? '') ?? 0;

      final modMatch = modifiedRegex.firstMatch(block);
      DateTime? modDate;
      final modStr = modMatch?.group(1)?.trim();
      if (modStr != null && modStr.isNotEmpty) {
        try {
          modDate = HttpDate.parse(modStr);
        } catch (_) {
          modDate = DateTime.tryParse(modStr);
        }
      }

      results.add(
        WebDavRemoteFile(
          name: name,
          href: href,
          sizeBytes: size,
          modifiedAt: modDate,
        ),
      );
    }

    // 按修改时间倒序排列
    results.sort((a, b) {
      if (a.modifiedAt == null || b.modifiedAt == null) return 0;
      return b.modifiedAt!.compareTo(a.modifiedAt!);
    });

    return results;
  }

  /// 删除远端文件。
  Future<void> deleteRemoteFile(String fileName) async {
    final client = _createHttpClient();
    try {
      final uri = _buildUri(fileName);
      final request = await client.openUrl('DELETE', uri).timeout(_connectTimeout);
      request.headers.set(HttpHeaders.authorizationHeader, _getAuthHeader());
      final response = await request.close().timeout(_responseTimeout);
      await response.drain<void>();
    } finally {
      client.close(force: true);
    }
  }
}
