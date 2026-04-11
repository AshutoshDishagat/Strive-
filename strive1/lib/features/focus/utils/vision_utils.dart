import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'dart:ui';

class VisionUtils {
  /// CameraImage
  static Future<InputImage?> buildInputImage({
    required CameraImage image,
    required CameraDescription camera,
    Uint8List? reusableBuffer,
  }) async {
    try {
      final int width = image.width;
      final int height = image.height;
      final planes = image.planes;

      // Handle
      if (planes.length == 1) {
        return InputImage.fromBytes(
          bytes: planes[0].bytes,
          metadata: InputImageMetadata(
            size: Size(width.toDouble(), height.toDouble()),
            rotation: _getRotation(camera.sensorOrientation),
            format: InputImageFormat.nv21,
            bytesPerRow: planes[0].bytesPerRow,
          ),
        );
      }

      // offloading
      if (planes.length >= 3) {
        final Map<String, dynamic> isolateParams = {
          'width': width,
          'height': height,
          'planeY': planes[0].bytes,
          'planeU': planes[1].bytes,
          'planeV': planes[2].bytes,
          'strideY': planes[0].bytesPerRow,
          'strideUV': planes[1].bytesPerRow,
          'bytesPerPixel': planes[1].bytesPerPixel,
        };

        final Uint8List nv21 =
            await compute(_convertYUV420ToNV21, isolateParams);

        return InputImage.fromBytes(
          bytes: nv21,
          metadata: InputImageMetadata(
            size: Size(width.toDouble(), height.toDouble()),
            rotation: _getRotation(camera.sensorOrientation),
            format: InputImageFormat.nv21,
            bytesPerRow: width,
          ),
        );
      }

      return null;
    } catch (e) {
      debugPrint("VisionUtils Error: $e");
      return null;
    }
  }

  static InputImageRotation _getRotation(int sensorOrientation) {
    switch (sensorOrientation) {
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return InputImageRotation.rotation0deg;
    }
  }
}

// function
Uint8List _convertYUV420ToNV21(Map<String, dynamic> params) {
  final int width = params['width'];
  final int height = params['height'];
  final Uint8List bytesY = params['planeY'];
  final Uint8List bytesU = params['planeU'];
  final Uint8List bytesV = params['planeV'];
  final int strideY = params['strideY'];
  final int strideUV = params['strideUV'];
  final int? bytesPerPixel = params['bytesPerPixel'];

  final int bufferSize = width * height * 3 ~/ 2;
  final Uint8List nv21 = Uint8List(bufferSize);

  int offset = 0;
  // Copy
  for (int y = 0; y < height; y++) {
    nv21.setRange(offset, offset + width, bytesY, y * strideY);
    offset += width;
  }

  // Interleave
  for (int y = 0; y < height ~/ 2; y++) {
    for (int x = 0; x < width ~/ 2; x++) {
      final int uvIndex = y * strideUV + x * (bytesPerPixel ?? 1);
      if (uvIndex < bytesV.length && uvIndex < bytesU.length) {
        nv21[offset++] = bytesV[uvIndex];
        nv21[offset++] = bytesU[uvIndex];
      }
    }
  }
  return nv21;
}
