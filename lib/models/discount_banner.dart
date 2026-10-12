class DiscountBanner {
  const DiscountBanner({
    required this.handle,
    required this.heading,
    required this.subtitle,
    required this.imageUrl,
    required this.discountTitle,
    required this.discountId,
    required this.sortOrder,
    required this.active,
    required this.showOverlay,
    this.imageAltText,
    this.startsAt,
    this.endsAt,
  });

  final String handle;
  final String heading;
  final String subtitle;
  final String imageUrl;
  final String? imageAltText;
  final String discountTitle;
  final String discountId;
  final int sortOrder;
  final bool active;
  final bool showOverlay;
  final DateTime? startsAt;
  final DateTime? endsAt;

  factory DiscountBanner.fromGraphQl(Map<String, dynamic> node) {
    final image = _reference(node, 'image')?['image'];
    final imageData = image is Map<String, dynamic> ? image : null;

    return DiscountBanner(
      handle: node['handle']?.toString().trim() ?? '',
      heading: _fieldValue(node, 'heading'),
      subtitle: _fieldValue(node, 'subtitle'),
      imageUrl: imageData?['url']?.toString().trim() ?? '',
      imageAltText: _optionalString(imageData?['altText']),
      discountTitle: _fieldValue(node, 'discountTitle'),
      discountId: _fieldValue(node, 'discountId'),
      sortOrder: int.tryParse(_fieldValue(node, 'sortOrder')) ?? 0,
      active: _fieldValue(node, 'active').toLowerCase() == 'true',
      showOverlay: _fieldValue(node, 'showOverlay').toLowerCase() != 'false',
      startsAt: DateTime.tryParse(_fieldValue(node, 'startsAt')),
      endsAt: DateTime.tryParse(_fieldValue(node, 'endsAt')),
    );
  }

  bool isVisibleAt(DateTime time) {
    if (!active || imageUrl.isEmpty || heading.isEmpty) return false;
    final instant = time.toUtc();
    if (startsAt != null && instant.isBefore(startsAt!.toUtc())) return false;
    if (endsAt != null && !instant.isBefore(endsAt!.toUtc())) return false;
    return true;
  }

  static String _fieldValue(Map<String, dynamic> node, String key) {
    final field = node[key];
    if (field is! Map<String, dynamic>) return '';
    return field['value']?.toString().trim() ?? '';
  }

  static Map<String, dynamic>? _reference(
    Map<String, dynamic> node,
    String key,
  ) {
    final field = node[key];
    if (field is! Map<String, dynamic>) return null;
    final reference = field['reference'];
    return reference is Map<String, dynamic> ? reference : null;
  }

  static String? _optionalString(Object? value) {
    final parsed = value?.toString().trim();
    return parsed == null || parsed.isEmpty ? null : parsed;
  }
}
