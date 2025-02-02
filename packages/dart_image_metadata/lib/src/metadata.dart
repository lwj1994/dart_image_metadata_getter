import 'dart:collection';
import 'dart:io';

import 'package:dart_image_metadata/dart_image_metadata.dart';

import 'decoder/impl/heif_decoder.dart';
import 'file_input.dart';

export 'core/input.dart';

///
/// [Size] is a class for image size.
///
/// The size contains [width] and [height].
///
///
/// ---
///
class ImageMetadata {
  final int width;
  final int height;
  final int bitDepth;
  final String mimeType;
  final Object? exception;

  String get extensionName =>
      mimeType.substring("image/".length, mimeType.length);

  /// {@template image_size_getter.Size.needToRotate}
  ///
  /// If the [needRotate] is true,
  /// the [width] and [height] need to be swapped when using.
  ///
  /// Such as, orientation value of the jpeg format is [5, 6, 7, 8].
  ///
  /// {@endtemplate}
  final int orientation;

  /// The [width] is zero and [height] is zero.
  static ImageMetadata none = const ImageMetadata();

  bool get isSuccess => width > 0 && height > 0 && exception == null;

//<editor-fold desc="Data Methods">

  const ImageMetadata({
    this.width = 0,
    this.height = 0,
    this.bitDepth = 0,
    this.mimeType = "image/png",
    this.orientation = 0,
    this.exception,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ImageMetadata &&
          runtimeType == other.runtimeType &&
          width == other.width &&
          height == other.height &&
          bitDepth == other.bitDepth &&
          mimeType == other.mimeType &&
          orientation == other.orientation);

  @override
  int get hashCode =>
      width.hashCode ^
      height.hashCode ^
      bitDepth.hashCode ^
      mimeType.hashCode ^
      orientation.hashCode;

  @override
  String toString() {
    return 'ImageMetaData{' +
        ' width: $width,' +
        ' height: $height,' +
        ' bitDepth: $bitDepth,' +
        ' mimeType: $mimeType,' +
        ' orientation: $orientation,' +
        '}';
  }

  ImageMetadata copyWith({
    int? width,
    int? height,
    int? bitDepth,
    String? mimeType,
    int? orientation,
  }) {
    return ImageMetadata(
      width: width ?? this.width,
      height: height ?? this.height,
      bitDepth: bitDepth ?? this.bitDepth,
      mimeType: mimeType ?? this.mimeType,
      orientation: orientation ?? this.orientation,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'width': this.width,
      'height': this.height,
      'bitDepth': this.bitDepth,
      'mimeType': this.mimeType,
      'orientation': this.orientation,
    };
  }

  factory ImageMetadata.fromMap(Map<String, dynamic> map) {
    return ImageMetadata(
      width: map['width'] as int,
      height: map['height'] as int,
      bitDepth: map['bitDepth'] as int,
      mimeType: map['mimeType'] as String,
      orientation: map['orientation'] as int,
    );
  }

  /// {@macro image_size_getter._DecoderContainer.register}
  static void registerDecoder(BaseDecoder decoder) {
    _decoders.registerDecoder(decoder);
  }

  static Future<ImageMetadata> getWithFilePath(String filePath) async {
    return get(FileInput(File(filePath)));
  }

  /// {@macro image_size_getter.getSize}
  ///
  /// The method is async.
  static Future<ImageMetadata> get(ImageInput input) async {
    if (!await input.exists()) {
      throw StateError('The input is not exists.');
    }

    if (!(await input.supportRangeLoad())) {
      final delegateInput = await input.delegateInput();
      try {
        return get(delegateInput);
      } finally {
        delegateInput.release();
      }
    }

    ImageMetadata imageMetadata = ImageMetadata.none;

    // 1. check valid
    for (var value in _decoders) {
      if (await value.isValid(input)) {
        imageMetadata = await value.parse(input);
      }
      if (imageMetadata.isSuccess) break;
    }

    if (!imageMetadata.isSuccess) {
      throw UnsupportedError(
          'The input is not supported. ${imageMetadata.exception ?? ""}');
    }
    return imageMetadata;
  }
//</editor-fold>
}

/// {@template image_size_getter._DecoderContainer}
///
/// [_DecoderContainer] is a container for [BaseDecoder]s.
///
/// {@endtemplate}
class _DecoderContainer extends IterableBase<BaseDecoder> {
  /// {@macro image_size_getter._DecoderContainer}
  _DecoderContainer(List<BaseDecoder> decoders) {
    for (final decoder in decoders) {
      _decoders[decoder.decoderName] = decoder;
    }
  }

  /// The [BaseDecoder]s.
  final Map<String, BaseDecoder> _decoders = {};

  /// {@template image_size_getter._DecoderContainer.register}
  ///
  /// Registers a [BaseDecoder] to the container.
  ///
  /// If the [BaseDecoder] is already registered, it will be replaced.
  ///
  /// {@endtemplate}
  void registerDecoder(BaseDecoder decoder) {
    _decoders[decoder.decoderName] = decoder;
  }

  @override
  Iterator<BaseDecoder> get iterator => _decoders.values.iterator;
}

/// The instance of [_DecoderContainer].
///
/// This instance is used to register [BaseDecoder]s, it will be used by [ImageMetadataGetter].
final _decoders = _DecoderContainer([
  const JpegDecoder(),
  const PngDecoder(),
  const GifDecoder(),
  const WebpDecoder(),
  HeifDecoder(),
  const BmpDecoder(),
]);
