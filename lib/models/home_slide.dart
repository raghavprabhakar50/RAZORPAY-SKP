class HomeSlide {
  const HomeSlide({
    required this.handle,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.buttonLabel,
    required this.sortOrder,
    required this.active,
    this.imageAltText,
    this.collectionId,
    this.collectionHandle,
    this.collectionTitle,
    this.collectionUrl,
  });

  final String handle;
  final String title;
  final String subtitle;
  final String imageUrl;
  final String? imageAltText;
  final String buttonLabel;
  final int sortOrder;
  final bool active;
  final String? collectionId;
  final String? collectionHandle;
  final String? collectionTitle;
  final String? collectionUrl;

  factory HomeSlide.fromGraphQl(Map<String, dynamic> node) {
    final image = _reference(node, 'image')?['image'];
    final imageData = image is Map<String, dynamic> ? image : null;
    final collection = _reference(node, 'collection');

    return HomeSlide(
      handle: _requiredString(node['handle'], 'handle'),
      title: _fieldValue(node, 'title'),
      subtitle: _fieldValue(node, 'subtitle'),
      imageUrl: _requiredString(imageData?['url'], 'image.url'),
      imageAltText: _optionalString(imageData?['altText']),
      buttonLabel: _fieldValue(node, 'buttonLabel'),
      sortOrder: int.tryParse(_fieldValue(node, 'sortOrder')) ?? 0,
      active: _fieldValue(node, 'active').toLowerCase() == 'true',
      collectionId: _optionalString(collection?['id']),
      collectionHandle: _optionalString(collection?['handle']),
      collectionTitle: _optionalString(collection?['title']),
      collectionUrl: _optionalString(collection?['onlineStoreUrl']),
    );
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

  static String _requiredString(Object? value, String fieldName) {
    final parsed = _optionalString(value);
    if (parsed == null) {
      throw FormatException('Home slider field "$fieldName" is missing.');
    }
    return parsed;
  }

  static String? _optionalString(Object? value) {
    final parsed = value?.toString().trim();
    return parsed == null || parsed.isEmpty ? null : parsed;
  }
}
