import 'dart:convert';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

class StorefrontCollection {
  const StorefrontCollection({
    required this.id,
    required this.handle,
    required this.title,
    this.imageUrl,
    this.imageAltText,
  });

  final String id;
  final String handle;
  final String title;
  final String? imageUrl;
  final String? imageAltText;

  factory StorefrontCollection.fromGraphQl(Map<String, dynamic> node) {
    final image = node['image'];
    final imageData = image is Map<String, dynamic> ? image : null;
    final products = node['products']?['nodes'];
    final firstProduct = products is List && products.isNotEmpty
        ? products.first
        : null;
    final fallbackImage = firstProduct is Map<String, dynamic>
        ? firstProduct['featuredImage']
        : null;
    final fallbackImageData = fallbackImage is Map<String, dynamic>
        ? fallbackImage
        : null;

    return StorefrontCollection(
      id: node['id']?.toString() ?? '',
      handle: node['handle']?.toString() ?? '',
      title: node['title']?.toString() ?? '',
      imageUrl:
          imageData?['url']?.toString() ??
          fallbackImageData?['url']?.toString(),
      imageAltText:
          imageData?['altText']?.toString() ??
          fallbackImageData?['altText']?.toString(),
    );
  }
}

class StorefrontProduct {
  const StorefrontProduct({
    required this.id,
    required this.handle,
    required this.title,
    required this.amount,
    required this.currencyCode,
    this.productType,
    this.imageUrl,
    this.imageAltText,
    this.description = '',
    this.descriptionHtml = '',
    this.descriptionSegments = const [],
    this.compareAtAmount,
    this.firstVariantId,
    this.availableForSale = true,
    this.images = const [],
    this.media = const [],
    this.shortDescription = '',
    this.shortDescriptionSegments = const [],
    this.variants = const [],
  });

  final String id;
  final String handle;
  final String title;
  final double amount;
  final String currencyCode;
  final String? productType;
  final String? imageUrl;
  final String? imageAltText;
  final String description;
  final String descriptionHtml;
  final List<StorefrontRichTextSegment> descriptionSegments;
  final double? compareAtAmount;
  final String? firstVariantId;
  final bool availableForSale;
  final List<StorefrontProductImage> images;
  final List<StorefrontProductMedia> media;
  final String shortDescription;
  final List<StorefrontRichTextSegment> shortDescriptionSegments;
  final List<StorefrontProductVariant> variants;

  factory StorefrontProduct.fromGraphQl(Map<String, dynamic> node) {
    final image = node['featuredImage'];
    final imageData = image is Map<String, dynamic> ? image : null;
    final minimumPrice = node['priceRange']?['minVariantPrice'];
    final priceData = minimumPrice is Map<String, dynamic>
        ? minimumPrice
        : null;
    final imageNodes = node['images']?['nodes'];
    final images = imageNodes is List
        ? imageNodes
              .whereType<Map<String, dynamic>>()
              .map(StorefrontProductImage.fromGraphQl)
              .where((image) => image.url.isNotEmpty)
              .toList(growable: false)
        : const <StorefrontProductImage>[];
    final mediaNodes = node['media']?['nodes'];
    final media = mediaNodes is List
        ? mediaNodes
              .whereType<Map<String, dynamic>>()
              .map(StorefrontProductMedia.fromGraphQl)
              .whereType<StorefrontProductMedia>()
              .toList(growable: false)
        : const <StorefrontProductMedia>[];
    final variantNodes = node['variants']?['nodes'];
    final variants = variantNodes is List
        ? variantNodes
              .whereType<Map<String, dynamic>>()
              .map(StorefrontProductVariant.fromGraphQl)
              .toList(growable: false)
        : const <StorefrontProductVariant>[];
    final firstVariant = variantNodes is List && variantNodes.isNotEmpty
        ? variantNodes.first
        : null;
    final variantData = firstVariant is Map<String, dynamic>
        ? firstVariant
        : null;
    final variantPrice = variantData?['price'];
    final variantPriceData = variantPrice is Map<String, dynamic>
        ? variantPrice
        : null;
    final compareAtPrice = variantData?['compareAtPrice'];
    final compareAtPriceData = compareAtPrice is Map<String, dynamic>
        ? compareAtPrice
        : null;

    final richSegments = _richTextSegments(node['shortDescriptionRich']);
    final shortDescriptionSegments = richSegments.isNotEmpty
        ? richSegments
        : _richTextSegments(node['shortDescription']);
    final descriptionHtml = node['descriptionHtml']?.toString().trim() ?? '';

    return StorefrontProduct(
      id: node['id']?.toString() ?? '',
      handle: node['handle']?.toString() ?? '',
      title: node['title']?.toString() ?? '',
      amount:
          double.tryParse(variantPriceData?['amount']?.toString() ?? '') ??
          double.tryParse(priceData?['amount']?.toString() ?? '') ??
          0,
      currencyCode:
          variantPriceData?['currencyCode']?.toString() ??
          priceData?['currencyCode']?.toString() ??
          'INR',
      productType: _optionalString(node['productType']),
      imageUrl: _optionalString(imageData?['url']),
      imageAltText: _optionalString(imageData?['altText']),
      description: node['description']?.toString().trim() ?? '',
      descriptionHtml: descriptionHtml,
      descriptionSegments: _htmlSegments(descriptionHtml),
      compareAtAmount: double.tryParse(
        compareAtPriceData?['amount']?.toString() ?? '',
      ),
      firstVariantId: _optionalString(variantData?['id']),
      availableForSale: variantData?['availableForSale'] as bool? ?? true,
      images: images,
      media: media,
      shortDescription: shortDescriptionSegments
          .map((segment) => segment.text)
          .join()
          .trim(),
      shortDescriptionSegments: shortDescriptionSegments,
      variants: variants,
    );
  }

  static List<StorefrontRichTextSegment> _richTextSegments(Object? field) {
    if (field is! Map<String, dynamic>) return const [];
    final value = field['value']?.toString().trim() ?? '';
    if (value.isEmpty) return const [];
    try {
      final decoded = jsonDecode(value);
      final segments = <StorefrontRichTextSegment>[];
      void collect(Object? node, {bool bold = false, bool italic = false}) {
        if (node is Map<String, dynamic>) {
          final nodeBold = node['bold'] as bool? ?? bold;
          final nodeItalic = node['italic'] as bool? ?? italic;
          final text = node['value'];
          final type = node['type']?.toString();
          if (type == 'list-item') {
            segments.add(const StorefrontRichTextSegment(text: '• '));
          }
          if (text is String && text.isNotEmpty) {
            segments.add(
              StorefrontRichTextSegment(
                text: text,
                bold: nodeBold,
                italic: nodeItalic,
              ),
            );
          }
          final children = node['children'];
          if (children is List) {
            for (final child in children) {
              collect(child, bold: nodeBold, italic: nodeItalic);
            }
          }
          if ((type == 'paragraph' || type == 'list-item') &&
              segments.isNotEmpty &&
              !segments.last.text.endsWith('\n')) {
            segments.add(const StorefrontRichTextSegment(text: '\n'));
          }
        }
      }

      collect(decoded);
      while (segments.isNotEmpty && segments.last.text.trim().isEmpty) {
        segments.removeLast();
      }
      return List.unmodifiable(segments);
    } on FormatException {
      return [StorefrontRichTextSegment(text: value)];
    }
  }

  static List<StorefrontRichTextSegment> _htmlSegments(String value) {
    if (value.isEmpty) return const [];
    final fragment = html_parser.parseFragment(value);
    final segments = <StorefrontRichTextSegment>[];

    void addBreak() {
      if (segments.isNotEmpty && !segments.last.text.endsWith('\n')) {
        segments.add(const StorefrontRichTextSegment(text: '\n'));
      }
    }

    void collect(dom.Node node, {bool bold = false, bool italic = false}) {
      if (node is dom.Text) {
        final text = node.data.replaceAll(RegExp(r'[ \t\r\f]+'), ' ');
        if (text.isNotEmpty) {
          segments.add(
            StorefrontRichTextSegment(text: text, bold: bold, italic: italic),
          );
        }
        return;
      }
      if (node is! dom.Element) {
        for (final child in node.nodes) {
          collect(child, bold: bold, italic: italic);
        }
        return;
      }

      final tag = node.localName ?? '';
      final nodeBold =
          bold || tag == 'strong' || tag == 'b' || tag.startsWith('h');
      final nodeItalic = italic || tag == 'em' || tag == 'i';
      if (tag == 'br') addBreak();
      if (tag == 'li') {
        segments.add(const StorefrontRichTextSegment(text: '• '));
      }
      for (final child in node.nodes) {
        collect(child, bold: nodeBold, italic: nodeItalic);
      }
      if (tag == 'p' || tag == 'li' || tag == 'div' || tag.startsWith('h')) {
        addBreak();
      }
    }

    for (final node in fragment.nodes) {
      collect(node);
    }
    while (segments.isNotEmpty && segments.last.text.trim().isEmpty) {
      segments.removeLast();
    }
    return List.unmodifiable(segments);
  }

  static String? _optionalString(Object? value) {
    final parsed = value?.toString().trim();
    return parsed == null || parsed.isEmpty ? null : parsed;
  }
}

class StorefrontRichTextSegment {
  const StorefrontRichTextSegment({
    required this.text,
    this.bold = false,
    this.italic = false,
  });

  final String text;
  final bool bold;
  final bool italic;
}

class StorefrontProductImage {
  const StorefrontProductImage({required this.url, this.altText});

  final String url;
  final String? altText;

  factory StorefrontProductImage.fromGraphQl(Map<String, dynamic> node) {
    return StorefrontProductImage(
      url: node['url']?.toString().trim() ?? '',
      altText: StorefrontProduct._optionalString(node['altText']),
    );
  }
}

enum StorefrontProductMediaType { image, video }

class StorefrontProductMedia {
  const StorefrontProductMedia({
    required this.type,
    required this.url,
    this.previewImageUrl,
    this.altText,
  });

  final StorefrontProductMediaType type;
  final String url;
  final String? previewImageUrl;
  final String? altText;

  static StorefrontProductMedia? fromGraphQl(Map<String, dynamic> node) {
    final type = node['__typename']?.toString();
    final preview = node['previewImage'];
    final previewData = preview is Map<String, dynamic> ? preview : null;
    if (type == 'MediaImage') {
      final image = node['image'];
      final imageData = image is Map<String, dynamic> ? image : null;
      final url = imageData?['url']?.toString().trim() ?? '';
      if (url.isEmpty) return null;
      return StorefrontProductMedia(
        type: StorefrontProductMediaType.image,
        url: url,
        previewImageUrl: url,
        altText: StorefrontProduct._optionalString(
          imageData?['altText'] ?? node['alt'],
        ),
      );
    }
    if (type == 'Video') {
      final sources = node['sources'];
      if (sources is! List || sources.isEmpty) return null;
      final sourceNodes = sources.whereType<Map<String, dynamic>>().toList();
      if (sourceNodes.isEmpty) return null;
      final preferred = sourceNodes.firstWhere(
        (source) => source['mimeType']?.toString() == 'video/mp4',
        orElse: () => sourceNodes.first,
      );
      final url = preferred['url']?.toString().trim() ?? '';
      if (url.isEmpty) return null;
      return StorefrontProductMedia(
        type: StorefrontProductMediaType.video,
        url: url,
        previewImageUrl: StorefrontProduct._optionalString(previewData?['url']),
        altText: StorefrontProduct._optionalString(
          node['alt'] ?? previewData?['altText'],
        ),
      );
    }
    return null;
  }
}

class StorefrontProductVariant {
  const StorefrontProductVariant({
    required this.id,
    required this.title,
    required this.amount,
    required this.currencyCode,
    required this.availableForSale,
    required this.selectedOptions,
    this.quantityAvailable,
    this.compareAtAmount,
    this.imageUrl,
  });

  final String id;
  final String title;
  final double amount;
  final String currencyCode;
  final double? compareAtAmount;
  final bool availableForSale;
  final int? quantityAvailable;
  final Map<String, String> selectedOptions;
  final String? imageUrl;

  factory StorefrontProductVariant.fromGraphQl(Map<String, dynamic> node) {
    final price = node['price'];
    final priceData = price is Map<String, dynamic> ? price : null;
    final compareAt = node['compareAtPrice'];
    final compareAtData = compareAt is Map<String, dynamic> ? compareAt : null;
    final image = node['image'];
    final imageData = image is Map<String, dynamic> ? image : null;
    final optionNodes = node['selectedOptions'];
    final selectedOptions = <String, String>{};
    if (optionNodes is List) {
      for (final option in optionNodes.whereType<Map<String, dynamic>>()) {
        final name = option['name']?.toString().trim() ?? '';
        final value = option['value']?.toString().trim() ?? '';
        if (name.isNotEmpty && value.isNotEmpty) selectedOptions[name] = value;
      }
    }

    return StorefrontProductVariant(
      id: node['id']?.toString() ?? '',
      title: node['title']?.toString().trim() ?? '',
      amount: double.tryParse(priceData?['amount']?.toString() ?? '') ?? 0,
      currencyCode: priceData?['currencyCode']?.toString() ?? 'INR',
      compareAtAmount: double.tryParse(
        compareAtData?['amount']?.toString() ?? '',
      ),
      availableForSale: node['availableForSale'] as bool? ?? false,
      quantityAvailable: (node['quantityAvailable'] as num?)?.toInt(),
      selectedOptions: Map.unmodifiable(selectedOptions),
      imageUrl: StorefrontProduct._optionalString(imageData?['url']),
    );
  }
}
