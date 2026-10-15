import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/tokens.dart';

/// 屙屎人头像截取编辑器。
///
/// 特性保证：
///   - 严格锁定原图真实宽高比，彻底移除视口强约束，杜绝长图被压扁变形；
///   - 动态无损提取原图真实物理像素（选多大裁多大，绝不大图粗暴压缩，也绝不小图虚假放大）；
///   - 导出纯正 1:1 正方形矩形图片（绝不破坏像素硬切圆角，上层 UI 自由遮罩）；
///   - 视口呈现 1:1 辅助暗房与优雅圆角虚线构图参考；
///   - 支持页内就地重新选图，杜绝闪跳回详情页的糟糕交互；
///   - 物理边界阻尼与双指丝滑缩放。
class AvatarCropperPage extends StatefulWidget {
  const AvatarCropperPage({
    super.key,
    required this.initialImageBytes,
  });

  final Uint8List initialImageBytes;

  @override
  State<AvatarCropperPage> createState() => _AvatarCropperPageState();
}

class _AvatarCropperPageState extends State<AvatarCropperPage> {
  final TransformationController _transformController =
      TransformationController();

  late Uint8List _imageBytes;
  ui.Image? _decodedImage;
  bool _loading = true;
  int _quarterTurns = 0; // 0: 0°, 1: 90°, 2: 180°, 3: 270°
  bool _cropping = false;

  static const double _cropSize = 280.0;
  static const double _cropRadius = 24.0;

  @override
  void initState() {
    super.initState();
    _imageBytes = widget.initialImageBytes;
    _loadImage(_imageBytes);
  }

  Future<void> _loadImage(Uint8List bytes) async {
    setState(() => _loading = true);
    try {
      final image = await decodeImageFromList(bytes);
      if (!mounted) return;
      setState(() {
        _imageBytes = bytes;
        _decodedImage = image;
        _quarterTurns = 0;
        _loading = false;
        _resetTransform();
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _transformController.dispose();
    _decodedImage?.dispose();
    super.dispose();
  }

  /// 原图旋转后的有效物理宽度
  double get _effW {
    if (_decodedImage == null) return _cropSize;
    return _quarterTurns % 2 == 1
        ? _decodedImage!.height.toDouble()
        : _decodedImage!.width.toDouble();
  }

  /// 原图旋转后的有效物理高度
  double get _effH {
    if (_decodedImage == null) return _cropSize;
    return _quarterTurns % 2 == 1
        ? _decodedImage!.width.toDouble()
        : _decodedImage!.height.toDouble();
  }

  /// 真实无损长宽比
  double get _aspectRatio => _effW / _effH;

  /// 计算在 _cropSize 视口下短边对齐时的显示尺寸（长边自然延伸，保持 100% 原始长宽比）
  Size get _contentSize {
    if (_aspectRatio >= 1.0) {
      // 横图：高为 _cropSize，宽按比例延展
      return Size(_cropSize * _aspectRatio, _cropSize);
    } else {
      // 竖图/长图：宽为 _cropSize，高按比例延展，绝不强行压缩为 1:1
      return Size(_cropSize, _cropSize / _aspectRatio);
    }
  }

  void _resetTransform() {
    final size = _contentSize;
    final initX = -(size.width - _cropSize) / 2;
    final initY = -(size.height - _cropSize) / 2;
    _transformController.value = Matrix4.identity()
      ..translate(initX, initY, 0.0);
  }

  void _rotateClockwise() {
    HapticFeedback.lightImpact();
    setState(() {
      _quarterTurns = (_quarterTurns + 1) % 4;
      _resetTransform();
    });
  }

  void _resetPosition() {
    HapticFeedback.lightImpact();
    setState(() {
      _quarterTurns = 0;
      _resetTransform();
    });
  }

  /// 在当前页面内直接挑选新照片并无缝热更新，避免跳回上一层页面
  Future<void> _pickAnotherPhoto() async {
    try {
      HapticFeedback.selectionClick();
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 95,
      );
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      await _loadImage(bytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('挑选照片失败: $e')),
        );
      }
    }
  }

  /// 完成截取：动态提取原图物理像素（选多大就是多大，零失真无损 1:1 矩形输出）
  Future<void> _completeCrop() async {
    if (_cropping || _decodedImage == null) return;
    HapticFeedback.mediumImpact();
    setState(() => _cropping = true);

    try {
      final matrix = _transformController.value;
      final double currentScale = matrix.getMaxScaleOnAxis().clamp(1.0, 10.0);

      // 计算裁剪框在 contentSize 上的覆盖跨度 (屏幕视口 / scale)
      final double cropSpanOnContent = _cropSize / currentScale;

      // content 尺寸与原图有效物理像素的映射比例
      final size = _contentSize;
      final double pixelPerUnit = _effW / size.width;

      // 原图上被裁切的正方形区域真实物理像素边长（不虚假放大，也不粗暴压缩）
      final double actualPixelSpan = cropSpanOnContent * pixelPerUnit;
      final int outputSize = actualPixelSpan.round().clamp(1, 4096);

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(
        recorder,
        Rect.fromLTWH(0, 0, outputSize.toDouble(), outputSize.toDouble()),
      );

      // 1. 严格 1:1 正方形矩形裁切，绝不抠除圆角
      canvas.clipRect(
        Rect.fromLTWH(0, 0, outputSize.toDouble(), outputSize.toDouble()),
      );

      // 2. 将屏幕视口映射到输出高分辨率物理画布
      final double scaleFactor = outputSize / _cropSize;
      canvas.scale(scaleFactor);
      canvas.transform(matrix.storage);

      // 3. 在视口中按与屏幕完全相同的几何模型绘制原图
      final rawW = _decodedImage!.width.toDouble();
      final rawH = _decodedImage!.height.toDouble();

      canvas.save();
      canvas.translate(size.width / 2, size.height / 2);
      if (_quarterTurns != 0) {
        canvas.rotate(_quarterTurns * (math.pi / 2));
      }

      final drawW = _quarterTurns % 2 == 1 ? size.height : size.width;
      final drawH = _quarterTurns % 2 == 1 ? size.width : size.height;

      canvas.drawImageRect(
        _decodedImage!,
        Rect.fromLTWH(0, 0, rawW, rawH),
        Rect.fromCenter(center: Offset.zero, width: drawW, height: drawH),
        Paint()..filterQuality = FilterQuality.high,
      );
      canvas.restore();

      final ui.Image croppedImage = await recorder.endRecording().toImage(
        outputSize,
        outputSize,
      );
      final ByteData? byteData =
          await croppedImage.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) return;
      final Uint8List croppedBytes = byteData.buffer.asUint8List();

      if (mounted) {
        Navigator.of(context).pop(croppedBytes);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('裁切图片失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _cropping = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final contentSize = _contentSize;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.x, color: Colors.white, size: 22),
          onPressed: () => Navigator.of(context).pop(null),
          tooltip: '取消',
        ),
        title: const Text(
          '调整头像截取区域',
          style: TextStyle(
            fontSize: 16.5,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.image, color: Colors.white, size: 20),
            onPressed: _loading ? null : _pickAnotherPhoto,
            tooltip: '换一张照片',
          ),
          IconButton(
            icon: const Icon(LucideIcons.rotateCw, color: Colors.white, size: 20),
            onPressed: _loading ? null : _rotateClockwise,
            tooltip: '旋转90°',
          ),
          IconButton(
            icon: const Icon(LucideIcons.refreshCw, color: Colors.white, size: 19),
            onPressed: _loading ? null : _resetPosition,
            tooltip: '复位',
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white,
              ),
            )
          : Stack(
              fit: StackFit.expand,
              children: [
                // 1. 中间可交互裁剪视口
                //    constrained: false 允许图片保持自身真实几何宽高比延展，绝不强行限制为 1:1 正方形导致长图变扁！
                Center(
                  child: SizedBox(
                    width: _cropSize,
                    height: _cropSize,
                    child: InteractiveViewer(
                      transformationController: _transformController,
                      constrained: false,
                      clipBehavior: Clip.none,
                      boundaryMargin: EdgeInsets.zero,
                      minScale: 1.0,
                      maxScale: 5.0,
                      child: SizedBox(
                        width: contentSize.width,
                        height: contentSize.height,
                        child: CustomPaint(
                          size: contentSize,
                          painter: _ImageRenderPainter(
                            image: _decodedImage!,
                            quarterTurns: _quarterTurns,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // 2. 经典半透明暗房遮罩与圆角辅助构图框
                IgnorePointer(
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: _CropOverlayPainter(
                      cropSize: _cropSize,
                      cropRadius: _cropRadius,
                    ),
                  ),
                ),

                // 3. 底部提示与确认使用操作面板
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: EdgeInsets.fromLTRB(
                      24,
                      16,
                      24,
                      MediaQuery.paddingOf(context).bottom + 20,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.85),
                          Colors.black,
                        ],
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '双指缩放特写 · 拖动调整头像取景',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.72),
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            // 换一张照片按钮
                            Expanded(
                              flex: 4,
                              child: OutlinedButton.icon(
                                onPressed: _cropping ? null : _pickAnotherPhoto,
                                icon: const Icon(LucideIcons.imagePlus, size: 16),
                                label: const Text('重选照片'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.4),
                                    width: 1.0,
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 13),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(PoopRadii.pill),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // 确认使用按钮
                            Expanded(
                              flex: 6,
                              child: ElevatedButton.icon(
                                onPressed: _cropping ? null : _completeCrop,
                                icon: _cropping
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(LucideIcons.check, size: 17),
                                label: Text(
                                  _cropping ? '正在截取...' : '确认使用头像',
                                  style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: t.brand,
                                  foregroundColor: Colors.white,
                                  elevation: 4,
                                  padding: const EdgeInsets.symmetric(vertical: 13),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(PoopRadii.pill),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

/// 纯粹的几何物理原图绘制器，100% 保持原始长宽比，严禁任何拉伸变形
class _ImageRenderPainter extends CustomPainter {
  const _ImageRenderPainter({
    required this.image,
    required this.quarterTurns,
  });

  final ui.Image image;
  final int quarterTurns;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    if (quarterTurns != 0) {
      canvas.rotate(quarterTurns * (math.pi / 2));
    }
    final rawW = image.width.toDouble();
    final rawH = image.height.toDouble();
    final isOdd = quarterTurns % 2 == 1;
    final drawW = isOdd ? size.height : size.width;
    final drawH = isOdd ? size.width : size.height;

    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, rawW, rawH),
      Rect.fromCenter(center: Offset.zero, width: drawW, height: drawH),
      Paint()..filterQuality = FilterQuality.high,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ImageRenderPainter oldDelegate) =>
      oldDelegate.image != image || oldDelegate.quarterTurns != quarterTurns;
}

/// 经典半透明遮罩暗房与取景参考框
class _CropOverlayPainter extends CustomPainter {
  const _CropOverlayPainter({
    required this.cropSize,
    required this.cropRadius,
  });

  final double cropSize;
  final double cropRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final double left = (size.width - cropSize) / 2;
    final double top = (size.height - cropSize) / 2;
    final Rect cropRect = Rect.fromLTWH(left, top, cropSize, cropSize);

    // 1. 全屏深色遮罩（72% 暗房遮光）
    final backgroundPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // 2. 挖空中间 1:1 视口
    final cutoutPath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(cropRect, Radius.circular(cropRadius)),
      );

    final overlayPath = Path.combine(
      PathOperation.difference,
      backgroundPath,
      cutoutPath,
    );

    final darkPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.72)
      ..style = PaintingStyle.fill;

    canvas.drawPath(overlayPath, darkPaint);

    // 3. 绘制细腻的高光白色圆角参考边框
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    canvas.drawRRect(
      RRect.fromRectAndRadius(cropRect, Radius.circular(cropRadius)),
      borderPaint,
    );

    // 4. 九宫格辅助线（淡白色网格，帮助构图对齐）
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    final cell = cropSize / 3;
    // 纵向两条
    canvas.drawLine(
      Offset(left + cell, top),
      Offset(left + cell, top + cropSize),
      gridPaint,
    );
    canvas.drawLine(
      Offset(left + cell * 2, top),
      Offset(left + cell * 2, top + cropSize),
      gridPaint,
    );
    // 横向两条
    canvas.drawLine(
      Offset(left, top + cell),
      Offset(left + cropSize, top + cell),
      gridPaint,
    );
    canvas.drawLine(
      Offset(left, top + cell * 2),
      Offset(left + cropSize, top + cell * 2),
      gridPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CropOverlayPainter oldDelegate) =>
      oldDelegate.cropSize != cropSize || oldDelegate.cropRadius != cropRadius;
}
