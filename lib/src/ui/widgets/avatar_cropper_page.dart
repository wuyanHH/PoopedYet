import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/tokens.dart';

/// 裁切页面退出动作
enum CropExitAction {
  /// 确认使用裁剪后的图片
  confirm,

  /// 取消当前图片裁切，返回相册重新挑选其他照片
  repick,

  /// 彻底放弃并退出
  cancel,
}

/// 裁切结果对象
class CropResult {
  const CropResult({
    required this.action,
    this.croppedBytes,
  });

  final CropExitAction action;
  final Uint8List? croppedBytes;

  static const repick = CropResult(action: CropExitAction.repick);
  static const cancel = CropResult(action: CropExitAction.cancel);
}

/// 屙屎人头像截取编辑器。
///
/// 功能特性：
///   - 全景可视暗房：超出裁切框的图像半透明可见，彻底消除视野盲区；
///   - 智能比例适配：竖图支持整幅上下滑动选景，横图支持左右滑动，双指特写缩放；
///   - 严格边界约束：图片自动保证覆盖裁切框，杜绝露黑穿帮；
///   - 原生硬件级高质量 PNG 头像导出，亚像素级抗锯齿对齐。
class AvatarCropperPage extends StatefulWidget {
  const AvatarCropperPage({
    super.key,
    required this.imageBytes,
  });

  final Uint8List imageBytes;

  @override
  State<AvatarCropperPage> createState() => _AvatarCropperPageState();
}

class _AvatarCropperPageState extends State<AvatarCropperPage> {
  final TransformationController _transformController =
      TransformationController();

  ui.Image? _decodedImage;
  bool _loading = true;
  int _quarterTurns = 0;
  bool _cropping = false;

  static const double _cropSize = 260.0;
  static const double _cropRadius = 28.0;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      final image = await decodeImageFromList(widget.imageBytes);
      if (!mounted) return;
      setState(() {
        _decodedImage = image;
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

  double get _effectiveW {
    if (_decodedImage == null) return _cropSize;
    final rawW = _decodedImage!.width.toDouble();
    final rawH = _decodedImage!.height.toDouble();
    return _quarterTurns % 2 == 1 ? rawH : rawW;
  }

  double get _effectiveH {
    if (_decodedImage == null) return _cropSize;
    final rawW = _decodedImage!.width.toDouble();
    final rawH = _decodedImage!.height.toDouble();
    return _quarterTurns % 2 == 1 ? rawW : rawH;
  }

  double get _aspect => _effectiveW / _effectiveH;

  // 使得短边刚好等于 _cropSize，长边向外自然延展，获得充足的拖拽平移行程
  double get _layoutW => _aspect < 1.0 ? _cropSize : _cropSize * _aspect;
  double get _layoutH => _aspect > 1.0 ? _cropSize : _cropSize / _aspect;

  void _resetTransform() {
    final initX = -(_layoutW - _cropSize) / 2;
    final initY = -(_layoutH - _cropSize) / 2;
    _transformController.value = Matrix4.translationValues(initX, initY, 0);
  }

  void _rotate() {
    setState(() {
      _quarterTurns = (_quarterTurns + 1) % 4;
      _resetTransform();
    });
  }

  void _reset() {
    setState(() {
      _quarterTurns = 0;
      _resetTransform();
    });
  }

  Future<void> _completeCrop() async {
    if (_cropping || _decodedImage == null) return;
    setState(() => _cropping = true);

    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(
        recorder,
        const Rect.fromLTWH(0, 0, _cropSize, _cropSize),
      );

      // 1. 裁剪为标准的平滑圆角矩形
      canvas.clipRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(0, 0, _cropSize, _cropSize),
          const Radius.circular(_cropRadius),
        ),
      );

      // 2. 应用当前手势缩放与位移矩阵
      canvas.transform(_transformController.value.storage);

      // 3. 在中心按旋转方向绘制原图
      final rawW = _decodedImage!.width.toDouble();
      final rawH = _decodedImage!.height.toDouble();
      final isRotatedOdd = _quarterTurns % 2 == 1;
      final drawW = isRotatedOdd ? _layoutH : _layoutW;
      final drawH = isRotatedOdd ? _layoutW : _layoutH;

      canvas.save();
      canvas.translate(_layoutW / 2, _layoutH / 2);
      if (_quarterTurns != 0) {
        canvas.rotate(_quarterTurns * (math.pi / 2));
      }
      canvas.drawImageRect(
        _decodedImage!,
        Rect.fromLTWH(0, 0, rawW, rawH),
        Rect.fromCenter(center: Offset.zero, width: drawW, height: drawH),
        Paint()..filterQuality = FilterQuality.high,
      );
      canvas.restore();

      final ui.Image cropped = await recorder.endRecording().toImage(
        _cropSize.toInt(),
        _cropSize.toInt(),
      );
      final ByteData? byteData =
          await cropped.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) return;
      final Uint8List croppedBytes = byteData.buffer.asUint8List();

      if (mounted) {
        Navigator.of(context).pop(
          CropResult(
            action: CropExitAction.confirm,
            croppedBytes: croppedBytes,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('截取图片失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _cropping = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          // 点击系统返回键，跳到上一层重新选择图片
          Navigator.of(context).pop(CropResult.repick);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(LucideIcons.chevronLeft, color: Colors.white, size: 24),
            onPressed: () => Navigator.of(context).pop(CropResult.repick),
            tooltip: '重选图片',
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
              icon: const Icon(LucideIcons.rotateCw, color: Colors.white, size: 20),
              onPressed: _loading ? null : _rotate,
              tooltip: '顺时针旋转90°',
            ),
            IconButton(
              icon: const Icon(LucideIcons.refreshCw, color: Colors.white, size: 19),
              onPressed: _loading ? null : _reset,
              tooltip: '重置位置',
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
                  // 1. 中间可交互裁剪视口（clipBehavior: Clip.none 允许完整延展至全景）
                  Center(
                    child: SizedBox(
                      width: _cropSize,
                      height: _cropSize,
                      child: InteractiveViewer(
                        transformationController: _transformController,
                        clipBehavior: Clip.none,
                        boundaryMargin: EdgeInsets.zero,
                        minScale: 1.0,
                        maxScale: 4.0,
                        child: SizedBox(
                          width: _layoutW,
                          height: _layoutH,
                          child: RotatedBox(
                            quarterTurns: _quarterTurns,
                            child: Image.memory(
                              widget.imageBytes,
                              width: _quarterTurns % 2 == 1 ? _layoutH : _layoutW,
                              height: _quarterTurns % 2 == 1 ? _layoutW : _layoutH,
                              fit: BoxFit.fill,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 2. 周围半透明暗房遮罩与取景限制辅助线（挖空 260x260 选区）
                  IgnorePointer(
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: _CropOverlayPainter(
                        cropSize: _cropSize,
                        cropRadius: _cropRadius,
                      ),
                    ),
                  ),

                  // 3. 底部操作指引与确认按钮
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: SafeArea(
                      top: false,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black,
                              Colors.black87,
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  LucideIcons.move,
                                  size: 13,
                                  color: Colors.white.withValues(alpha: 0.65),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '单指拖动对齐 · 双指缩放特写',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withValues(alpha: 0.8),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                // 重新选择按钮
                                Expanded(
                                  flex: 4,
                                  child: SizedBox(
                                    height: 48,
                                    child: OutlinedButton.icon(
                                      onPressed: _cropping
                                          ? null
                                          : () => Navigator.of(context)
                                              .pop(CropResult.repick),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.white,
                                        side: BorderSide(
                                          color: Colors.white
                                              .withValues(alpha: 0.35),
                                          width: 1.2,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                              PoopRadii.pill),
                                        ),
                                      ),
                                      icon: const Icon(LucideIcons.images,
                                          size: 16),
                                      label: const Text(
                                        '重选照片',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // 确认保存按钮
                                Expanded(
                                  flex: 6,
                                  child: SizedBox(
                                    height: 48,
                                    child: ElevatedButton(
                                      onPressed:
                                          _cropping ? null : _completeCrop,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: t.brandFill,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                              PoopRadii.pill),
                                        ),
                                      ),
                                      child: _cropping
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Text(
                                              '确定使用',
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: 0.8,
                                              ),
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
                  ),
                ],
              ),
      ),
    );
  }
}

/// 裁剪框外周遮罩、限定边框与辅助角标绘制器。
class _CropOverlayPainter extends CustomPainter {
  const _CropOverlayPainter({
    required this.cropSize,
    required this.cropRadius,
  });

  final double cropSize;
  final double cropRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final cropRect = Rect.fromCenter(
      center: center,
      width: cropSize,
      height: cropSize,
    );
    final cropRRect = RRect.fromRectAndRadius(
      cropRect,
      Radius.circular(cropRadius),
    );

    // 1. 周围暗角遮罩（反向挖空）
    final bgPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final holePath = Path()..addRRect(cropRRect);
    final maskPath = Path.combine(PathOperation.difference, bgPath, holePath);

    final maskPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.72)
      ..style = PaintingStyle.fill;
    canvas.drawPath(maskPath, maskPaint);

    // 2. 裁剪框限定边框（强化边框限制感）
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRRect(cropRRect, borderPaint);

    // 3. 增强四角定位指示标识（Corner Handles），强化边界存在感
    final cornerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    const cornerLen = 22.0;
    // 左上角
    canvas.drawLine(
      Offset(cropRect.left, cropRect.top + cornerLen),
      Offset(cropRect.left, cropRect.top + cropRadius),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(cropRect.left + cropRadius, cropRect.top),
      Offset(cropRect.left + cornerLen, cropRect.top),
      cornerPaint,
    );

    // 右上角
    canvas.drawLine(
      Offset(cropRect.right, cropRect.top + cornerLen),
      Offset(cropRect.right, cropRect.top + cropRadius),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(cropRect.right - cornerLen, cropRect.top),
      Offset(cropRect.right - cropRadius, cropRect.top),
      cornerPaint,
    );

    // 左下角
    canvas.drawLine(
      Offset(cropRect.left, cropRect.bottom - cornerLen),
      Offset(cropRect.left, cropRect.bottom - cropRadius),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(cropRect.left + cropRadius, cropRect.bottom),
      Offset(cropRect.left + cornerLen, cropRect.bottom),
      cornerPaint,
    );

    // 右下角
    canvas.drawLine(
      Offset(cropRect.right, cropRect.bottom - cornerLen),
      Offset(cropRect.right, cropRect.bottom - cropRadius),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(cropRect.right - cornerLen, cropRect.bottom),
      Offset(cropRect.right - cropRadius, cropRect.bottom),
      cornerPaint,
    );

    // 4. 九宫格三分构图辅助线（轻度半透明）
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final cellW = cropSize / 3;
    final cellH = cropSize / 3;

    // 垂直辅助线
    canvas.drawLine(
      Offset(cropRect.left + cellW, cropRect.top + 4),
      Offset(cropRect.left + cellW, cropRect.bottom - 4),
      gridPaint,
    );
    canvas.drawLine(
      Offset(cropRect.left + cellW * 2, cropRect.top + 4),
      Offset(cropRect.left + cellW * 2, cropRect.bottom - 4),
      gridPaint,
    );

    // 水平辅助线
    canvas.drawLine(
      Offset(cropRect.left + 4, cropRect.top + cellH),
      Offset(cropRect.right - 4, cropRect.top + cellH),
      gridPaint,
    );
    canvas.drawLine(
      Offset(cropRect.left + 4, cropRect.top + cellH * 2),
      Offset(cropRect.right - 4, cropRect.top + cellH * 2),
      gridPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CropOverlayPainter oldDelegate) {
    return oldDelegate.cropSize != cropSize ||
        oldDelegate.cropRadius != cropRadius;
  }
}
