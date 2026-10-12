import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../data/product_details_data.dart';
import '../../models/home_catalog.dart';
import '../../services/shopping_store.dart';
import '../../services/shopify_storefront_service.dart';
import '../../widgets/app_shimmer.dart';
import '../cart/cart_screen.dart';

class ProductDetailsScreen extends StatefulWidget {
  const ProductDetailsScreen({
    required this.product,
    required this.storefrontService,
    super.key,
  });

  final StorefrontProduct product;
  final ShopifyStorefrontService storefrontService;

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  static const _brown = Color(0xff9d6043);
  static const _gold = Color(0xffffc967);

  late final Future<StorefrontProduct> _details;
  late final Future<List<StorefrontProduct>> _relatedProducts;
  int _selectedImage = 0;
  int _selectedVariant = 0;
  String _giftCard = 'Not Required';
  String _giftMessage = '';

  @override
  void initState() {
    super.initState();
    _details = widget.storefrontService.fetchProduct(widget.product.handle);
    _relatedProducts = widget.storefrontService.fetchRelatedProducts(
      widget.product.id,
    );
  }

  Future<void> _chooseGiftCard() async {
    final result = await showModalBottomSheet<({String card, String message})>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xfffbfaf8),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) =>
          _GiftCardSheet(initialCard: _giftCard, initialMessage: _giftMessage),
    );
    if (result != null && mounted) {
      setState(() {
        _giftCard = result.card;
        _giftMessage = result.message;
      });
    }
  }

  Future<void> _shareProduct(StorefrontProduct product) async {
    final productUrl = Uri.https(
      'srikrishnapearls.com',
      '/products/${product.handle}',
    );
    try {
      await SharePlus.instance.share(
        ShareParams(
          subject: product.title,
          text: '${product.title}\n$productUrl',
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Unable to open sharing options.')),
        );
    }
  }

  Future<void> _openShippingTerms() async {
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(
          'https://srikrishnapearls.com/policies/terms-of-service#hyderabad-shipping',
        ),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      opened = false;
    }
    if (!opened && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Unable to open shipping terms.')),
        );
    }
  }

  void _selectProductOption(
    StorefrontProduct product,
    String optionName,
    String value,
  ) {
    if (product.variants.isEmpty) return;
    final currentIndex = _selectedVariant.clamp(0, product.variants.length - 1);
    final desired = Map<String, String>.from(
      product.variants[currentIndex].selectedOptions,
    )..[optionName] = value;

    var nextIndex = product.variants.indexWhere(
      (variant) => desired.entries.every(
        (entry) => variant.selectedOptions[entry.key] == entry.value,
      ),
    );
    nextIndex = nextIndex >= 0
        ? nextIndex
        : product.variants.indexWhere(
            (variant) => variant.selectedOptions[optionName] == value,
          );
    if (nextIndex < 0) return;

    setState(() {
      _selectedVariant = nextIndex;
      final variantImage = product.variants[nextIndex].imageUrl;
      if (variantImage != null) {
        final imageIndex = product.media.isNotEmpty
            ? product.media.indexWhere(
                (media) =>
                    media.type == StorefrontProductMediaType.image &&
                    media.url == variantImage,
              )
            : product.images.indexWhere((image) => image.url == variantImage);
        if (imageIndex >= 0) _selectedImage = imageIndex;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: FutureBuilder<StorefrontProduct>(
        future: _details,
        initialData: widget.product,
        builder: (context, snapshot) {
          final product = snapshot.data ?? widget.product;
          final variant = product.variants.isEmpty
              ? null
              : product.variants[_selectedVariant.clamp(
                  0,
                  product.variants.length - 1,
                )];
          final shortDescription = product.shortDescription.isNotEmpty
              ? product.shortDescription
              : product.description;
          final productOptions = _ProductOptionsSelector.supportedOptionNames(
            product.variants,
          );
          return SafeArea(
            child: Column(
              children: [
                _ProductHeader(
                  onBack: () => Navigator.of(context).pop(),
                  onShare: () => _shareProduct(product),
                  onCart: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => CartScreen(
                        storefrontService: widget.storefrontService,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ProductGallery(
                          product: product,
                          selected: _selectedImage,
                          onSale:
                              (variant?.compareAtAmount ??
                                  product.compareAtAmount ??
                                  0) >
                              (variant?.amount ?? product.amount),
                          onSelected: (index) {
                            setState(() => _selectedImage = index);
                          },
                        ),
                        const SizedBox(height: 14),
                        if ((product.productType ?? '').isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xffffdf9b),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              product.productType!,
                              style: const TextStyle(
                                color: Color(0xff77503d),
                                fontSize: 10,
                              ),
                            ),
                          ),
                        const SizedBox(height: 7),
                        Text(
                          product.title,
                          style: const TextStyle(
                            color: _brown,
                            fontFamily: 'Fraunces',
                            fontSize: 25,
                            height: 1.18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (shortDescription.isNotEmpty) ...[
                          const SizedBox(height: 5),
                          _ShortDescription(
                            segments: product.shortDescriptionSegments,
                            fallback: product.description,
                          ),
                        ],
                        const SizedBox(height: 18),
                        _DeliveryInfoCard(onTermsPressed: _openShippingTerms),
                        if (productOptions.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          _ProductOptionsSelector(
                            variants: product.variants,
                            selected: _selectedVariant,
                            optionNames: productOptions,
                            onSelected: (option) => _selectProductOption(
                              product,
                              option.name,
                              option.value,
                            ),
                          ),
                          const SizedBox(height: 21),
                        ] else
                          const SizedBox(height: 20),
                        _PriceRow(product: product, variant: variant),
                        const SizedBox(height: 22),
                        _GiftCardButton(
                          selectedCard: _giftCard,
                          onPressed: _chooseGiftCard,
                        ),
                        const SizedBox(height: 25),
                        const _PurchaseBenefits(),
                        const SizedBox(height: 25),
                        const Divider(color: Color(0x229d6043)),
                        _DetailsTile(
                          title: 'Product Details',
                          body: product.description.isEmpty
                              ? 'Product information is available from Shopify.'
                              : product.description,
                          htmlBody: product.descriptionHtml,
                          richBody: product.descriptionSegments,
                        ),
                        const _DetailsTile(
                          title: 'Delivery & Returns',
                          body: 'Delivery time and return eligibility are confirmed at checkout.',
                        ),
                        const _DetailsTile(
                          title: 'Product Care',
                          body: 'Store separately and avoid direct contact with perfume, water and chemicals.',
                        ),
                        const SizedBox(height: 22),
                        _RelatedProducts(
                          products: _relatedProducts,
                          storefrontService: widget.storefrontService,
                        ),
                      ],
                    ),
                  ),
                ),
                _ProductActions(
                  favorite: ShoppingStore.instance.isWishlisted(product.handle),
                  available:
                      variant?.availableForSale ?? product.availableForSale,
                  onFavorite: () {
                    final added = ShoppingStore.instance.toggleWishlist(
                      product,
                    );
                    setState(() {});
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        SnackBar(
                          content: Text(
                            added
                                ? 'Added to wishlist.'
                                : 'Removed from wishlist.',
                          ),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                  },
                  onAddToCart: () {
                    ShoppingStore.instance.addToCart(
                      product: product,
                      variant: variant,
                      giftCard: _giftCard,
                      giftMessage: _giftMessage,
                    );
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        const SnackBar(
                          content: Text('Added to cart.'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ProductHeader extends StatelessWidget {
  const _ProductHeader({
    required this.onBack,
    required this.onShare,
    required this.onCart,
  });

  final VoidCallback onBack;
  final VoidCallback onShare;
  final VoidCallback onCart;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Row(
        children: [
          _RoundIcon(icon: Icons.arrow_back_ios_new_rounded, onTap: onBack),
          const Spacer(),
          _RoundIcon(icon: Icons.share_outlined, onTap: onShare),
          const SizedBox(width: 10),
          AnimatedBuilder(
            animation: ShoppingStore.instance,
            builder: (context, _) => _RoundIcon(
              icon: Icons.shopping_cart_outlined,
              onTap: onCart,
              badgeCount: ShoppingStore.instance.cartCount,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({
    required this.icon,
    required this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: Colors.white,
          shape: const CircleBorder(),
          elevation: 3,
          shadowColor: const Color(0x24000000),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 42,
              height: 42,
              child: Icon(icon, color: const Color(0xff554b45), size: 22),
            ),
          ),
        ),
        if (badgeCount > 0)
          Positioned(
            right: -4,
            top: -5,
            child: Container(
              constraints: const BoxConstraints(minWidth: 19, minHeight: 19),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xffa66042),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              alignment: Alignment.center,
              child: Text(
                badgeCount > 99 ? '99+' : '$badgeCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ProductGallery extends StatefulWidget {
  const _ProductGallery({
    required this.product,
    required this.selected,
    required this.onSale,
    required this.onSelected,
  });

  final StorefrontProduct product;
  final int selected;
  final bool onSale;
  final ValueChanged<int> onSelected;

  @override
  State<_ProductGallery> createState() => _ProductGalleryState();
}

class _ProductGalleryState extends State<_ProductGallery> {
  late final PageController _pageController;

  List<StorefrontProductMedia> get _media {
    if (widget.product.media.isNotEmpty) return widget.product.media;
    if (widget.product.images.isNotEmpty) {
      return widget.product.images
          .map(
            (image) => StorefrontProductMedia(
              type: StorefrontProductMediaType.image,
              url: image.url,
              previewImageUrl: image.url,
              altText: image.altText,
            ),
          )
          .toList(growable: false);
    }
    if (widget.product.imageUrl != null) {
      return [
        StorefrontProductMedia(
          type: StorefrontProductMediaType.image,
          url: widget.product.imageUrl!,
          previewImageUrl: widget.product.imageUrl!,
          altText: widget.product.imageAltText,
        ),
      ];
    }
    return const [];
  }

  int _safePage(int page, int itemCount) {
    return itemCount == 0 ? 0 : page.clamp(0, itemCount - 1);
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: _safePage(widget.selected, _media.length),
    );
  }

  @override
  void didUpdateWidget(covariant _ProductGallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected == widget.selected || !_pageController.hasClients) {
      return;
    }
    final target = _safePage(widget.selected, _media.length);
    final current = _pageController.page?.round();
    if (current == target) return;
    _pageController.animateToPage(
      target,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = _media;
    final safeSelected = media.isEmpty
        ? 0
        : widget.selected.clamp(0, media.length - 1);
    return AspectRatio(
      aspectRatio: .92,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: const Color(0xffebe7e3),
              child: media.isEmpty
                  ? const Icon(
                      Icons.diamond_outlined,
                      color: Color(0xffb99578),
                      size: 70,
                    )
                  : PageView.builder(
                      controller: _pageController,
                      itemCount: media.length,
                      onPageChanged: widget.onSelected,
                      itemBuilder: (context, index) {
                        final item = media[index];
                        if (item.type == StorefrontProductMediaType.video) {
                          if (index != safeSelected &&
                              item.previewImageUrl != null) {
                            return ShimmerNetworkImage(
                              url: item.previewImageUrl!,
                              fit: BoxFit.cover,
                            );
                          }
                          return _AutoPlayVideo(
                            key: ValueKey(item.url),
                            url: item.url,
                            previewImageUrl: item.previewImageUrl,
                          );
                        }
                        return GestureDetector(
                          onTap: () => _showZoom(context, item),
                          child: ShimmerNetworkImage(
                            url: item.url,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const Icon(
                              Icons.image_not_supported_outlined,
                              color: Color(0xffb99578),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            if (widget.onSale)
              Positioned(
                left: 13,
                top: 13,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xffa96445),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Text(
                    'SALE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: .7,
                    ),
                  ),
                ),
              ),
            if (media.length > 1)
              Positioned(
                left: 0,
                right: 0,
                bottom: 12,
                child: SizedBox(
                  height: 51,
                  child: Center(
                    child: ListView.separated(
                      shrinkWrap: true,
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: media.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 3),
                      itemBuilder: (context, index) {
                        final item = media[index];
                        final preview = item.previewImageUrl;
                        return GestureDetector(
                          onTap: () => widget.onSelected(index),
                          child: Container(
                            width: 51,
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(7),
                              border: Border.all(
                                color: index == safeSelected
                                    ? _ProductDetailsScreenState._gold
                                    : Colors.white,
                                width: 2,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  if (preview != null)
                                    ShimmerNetworkImage(
                                      url: preview,
                                      fit: BoxFit.cover,
                                    )
                                  else
                                    const ColoredBox(
                                      color: Color(0xffddd5cf),
                                      child: Icon(Icons.videocam_outlined),
                                    ),
                                  if (item.type ==
                                      StorefrontProductMediaType.video)
                                    const Center(
                                      child: Icon(
                                        Icons.play_circle_fill,
                                        color: Colors.white,
                                        size: 25,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static Future<void> _showZoom(
    BuildContext context,
    StorefrontProductMedia image,
  ) {
    return showDialog<void>(
      context: context,
      barrierColor: const Color(0xee000000),
      builder: (context) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 5,
                  child: Center(
                    child: ShimmerNetworkImage(
                      url: image.url,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton.filled(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AutoPlayVideo extends StatefulWidget {
  const _AutoPlayVideo({required this.url, this.previewImageUrl, super.key});

  final String url;
  final String? previewImageUrl;

  @override
  State<_AutoPlayVideo> createState() => _AutoPlayVideoState();
}

class _AutoPlayVideoState extends State<_AutoPlayVideo> {
  VideoPlayerController? _controller;
  late final Future<void> _initialization;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _initialization = _initialize();
  }

  Future<void> _initialize() async {
    final controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _controller = controller;
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(0);
      await controller.play();
    } catch (error, stackTrace) {
      _error = error;
      debugPrint('Product video initialization failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initialization,
      builder: (context, snapshot) {
        final controller = _controller;
        if (_error != null) {
          return Stack(
            fit: StackFit.expand,
            children: [
              if (widget.previewImageUrl != null)
                ShimmerNetworkImage(
                  url: widget.previewImageUrl!,
                  fit: BoxFit.cover,
                ),
              const ColoredBox(color: Color(0x22000000)),
              const Center(
                child: Icon(
                  Icons.videocam_off_outlined,
                  color: Color(0xff9d6043),
                  size: 34,
                ),
              ),
            ],
          );
        }
        if (snapshot.connectionState != ConnectionState.done ||
            controller == null ||
            !controller.value.isInitialized) {
          return const AppShimmer(child: ShimmerBox(borderRadius: 0));
        }
        return Center(
          child: AspectRatio(
            aspectRatio: controller.value.aspectRatio,
            child: VideoPlayer(controller),
          ),
        );
      },
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({required this.product, this.variant});

  final StorefrontProduct product;
  final StorefrontProductVariant? variant;

  @override
  Widget build(BuildContext context) {
    final amount = variant?.amount ?? product.amount;
    final currencyCode = variant?.currencyCode ?? product.currencyCode;
    final compareAt = variant?.compareAtAmount ?? product.compareAtAmount;
    final hasDiscount = compareAt != null && compareAt > amount;
    final percentage = hasDiscount
        ? (((compareAt - amount) / compareAt) * 100).round()
        : 0;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 9,
      runSpacing: 5,
      children: [
        Text(
          _price(amount, currencyCode),
          style: const TextStyle(
            color: _ProductDetailsScreenState._brown,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (hasDiscount)
          Text(
            _price(compareAt, currencyCode),
            style: const TextStyle(
              color: Color(0xff9a8f88),
              fontSize: 12,
              decoration: TextDecoration.lineThrough,
            ),
          ),
        if (hasDiscount)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xffffcf72),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$percentage% OFF',
              style: const TextStyle(
                color: Color(0xff76513d),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }

  static String _price(double amount, String currency) {
    final value = amount.round().toString();
    return currency == 'INR' ? 'Rs $value' : '$currency $value';
  }
}

class _ProductOptionsSelector extends StatelessWidget {
  const _ProductOptionsSelector({
    required this.variants,
    required this.selected,
    required this.optionNames,
    required this.onSelected,
  });

  final List<StorefrontProductVariant> variants;
  final int selected;
  final List<String> optionNames;
  final ValueChanged<({String name, String value})> onSelected;

  static List<String> supportedOptionNames(
    List<StorefrontProductVariant> variants,
  ) {
    final names = <String>[];
    for (final variant in variants) {
      for (final name in variant.selectedOptions.keys) {
        final normalized = name.toLowerCase();
        final supported =
            normalized.contains('grade') ||
            normalized.contains('size') ||
            normalized.contains('shade');
        if (supported && !names.contains(name)) names.add(name);
      }
    }
    return List.unmodifiable(names);
  }

  @override
  Widget build(BuildContext context) {
    final current = variants[selected.clamp(0, variants.length - 1)];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: optionNames
          .map((optionName) {
            final values = <String>[];
            for (final variant in variants) {
              final value = variant.selectedOptions[optionName];
              if (value != null && !values.contains(value)) values.add(value);
            }
            final isShade = optionName.toLowerCase().contains('shade');
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    optionName,
                    style: const TextStyle(
                      color: Color(0xff574335),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 9,
                    runSpacing: 8,
                    children: values
                        .map((value) {
                          final active =
                              current.selectedOptions[optionName] == value;
                          final shadeColor =
                              value.toLowerCase().contains('ivory')
                              ? const Color(0xfffff4d6)
                              : Colors.white;
                          return ChoiceChip(
                            selected: active,
                            onSelected: (_) =>
                                onSelected((name: optionName, value: value)),
                            backgroundColor: Colors.white,
                            selectedColor: const Color(0xffffe1a7),
                            side: BorderSide(
                              color: active
                                  ? _ProductDetailsScreenState._brown
                                  : const Color(0xffddd5cf),
                            ),
                            avatar: isShade
                                ? Container(
                                    width: 18,
                                    height: 18,
                                    decoration: BoxDecoration(
                                      color: shadeColor,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: const Color(0xffbdb3aa),
                                      ),
                                    ),
                                  )
                                : null,
                            label: Text(
                              value,
                              style: const TextStyle(fontSize: 15),
                            ),
                          );
                        })
                        .toList(growable: false),
                  ),
                ],
              ),
            );
          })
          .toList(growable: false),
    );
  }
}

class _ShortDescription extends StatelessWidget {
  const _ShortDescription({required this.segments, required this.fallback});

  final List<StorefrontRichTextSegment> segments;
  final String fallback;

  @override
  Widget build(BuildContext context) {
    const baseStyle = TextStyle(
      color: Color(0xff625b57),
      fontSize: 15,
      height: 1.75,
    );
    if (segments.isEmpty) {
      return Text(
        fallback,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: baseStyle,
      );
    }
    return RichText(
      maxLines: 8,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: baseStyle,
        children: segments
            .map(
              (segment) => TextSpan(
                text: segment.text,
                style: TextStyle(
                  fontWeight: segment.bold ? FontWeight.w700 : FontWeight.w400,
                  fontStyle: segment.italic
                      ? FontStyle.italic
                      : FontStyle.normal,
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _DeliveryInfoCard extends StatelessWidget {
  const _DeliveryInfoCard({required this.onTermsPressed});

  final VoidCallback onTermsPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xfffdfcfb),
        border: Border.all(color: const Color(0xffb89a79)),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Get delivery in Hyderabad in 2 working hours',
            style: TextStyle(
              color: Color(0xffaa8e6d),
              fontSize: 16,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '(Pan India Delivery 3-5 days. Express Delivery 24-48hrs on request)',
            style: TextStyle(
              color: Color(0xffaa8e6d),
              fontSize: 14,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 2),
          InkWell(
            onTap: onTermsPressed,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 2),
              child: Text(
                'TnC',
                style: TextStyle(
                  color: Color(0xff5a2582),
                  fontSize: 15,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GiftCardButton extends StatelessWidget {
  const _GiftCardButton({required this.selectedCard, required this.onPressed});

  final String selectedCard;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Complimentary Message Card',
          style: TextStyle(color: Color(0xff574335), fontSize: 14),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xff3d342f),
              side: const BorderSide(color: Color(0xff574335)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(7),
              ),
            ),
            child: Text(
              selectedCard == 'Not Required'
                  ? 'Choose Gift Card'
                  : selectedCard,
              style: const TextStyle(fontSize: 15),
            ),
          ),
        ),
      ],
    );
  }
}

class _GiftCardSheet extends StatefulWidget {
  const _GiftCardSheet({
    required this.initialCard,
    required this.initialMessage,
  });

  final String initialCard;
  final String initialMessage;

  @override
  State<_GiftCardSheet> createState() => _GiftCardSheetState();
}

class _GiftCardSheetState extends State<_GiftCardSheet> {
  late final TextEditingController _messageController;
  late String _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialCard;
    _messageController = TextEditingController(text: widget.initialMessage);
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 22,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Complimentary Message Card',
              style: TextStyle(
                color: Color(0xff574335),
                fontFamily: 'Fraunces',
                fontSize: 23,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            _GiftCardGrid(
              selected: _selected,
              onSelected: (value) => setState(() => _selected = value),
            ),
            if (_selected != 'Not Required') ...[
              const SizedBox(height: 18),
              TextField(
                controller: _messageController,
                maxLength: 250,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Message to be handwritten on the card',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop((
                  card: _selected,
                  message: _selected == 'Not Required'
                      ? ''
                      : _messageController.text.trim(),
                )),
                style: FilledButton.styleFrom(
                  backgroundColor: _ProductDetailsScreenState._brown,
                ),
                child: const Text(
                  'Save Selection',
                  style: TextStyle(fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PurchaseBenefits extends StatelessWidget {
  const _PurchaseBenefits();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'Included With Every Purchase',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xff574335),
            fontFamily: 'Fraunces',
            fontSize: 21,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = (constraints.maxWidth - 10) / 2;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: purchaseBenefits
                  .map(
                    (benefit) => Container(
                      width: width,
                      height: 105,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0d000000),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 43,
                            height: 43,
                            decoration: const BoxDecoration(
                              color: Color(0xfffbfaf8),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0x15000000),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(9),
                              child: SvgPicture.asset(
                                benefit.asset,
                                colorFilter: const ColorFilter.mode(
                                  Color(0xff6d5548),
                                  BlendMode.srcIn,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            child: Text(
                              benefit.label,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xff574335),
                                fontFamily: 'Fraunces',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(growable: false),
            );
          },
        ),
      ],
    );
  }
}

class _GiftCardGrid extends StatelessWidget {
  const _GiftCardGrid({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: giftCardOptions.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.35,
      ),
      itemBuilder: (context, index) {
        final card = giftCardOptions[index];
        final active = selected == card.name;
        return InkWell(
          onTap: () => onSelected(card.name),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: active
                    ? _ProductDetailsScreenState._gold
                    : const Color(0xffe2dcd7),
                width: active ? 3 : 1,
              ),
            ),
            child: card.imageUrl == null
                ? Center(
                    child: Text(
                      card.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ShimmerNetworkImage(
                          url: card.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const ColoredBox(
                            color: Color(0xfff2eee9),
                            child: Icon(
                              Icons.card_giftcard,
                              color: Color(0xff9d6043),
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            color: const Color(0xb3000000),
                            child: Text(
                              card.name,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }
}

class _RelatedProducts extends StatelessWidget {
  const _RelatedProducts({
    required this.products,
    required this.storefrontService,
  });

  final Future<List<StorefrontProduct>> products;
  final ShopifyStorefrontService storefrontService;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<StorefrontProduct>>(
      future: products,
      builder: (context, snapshot) {
        final items = snapshot.data ?? const <StorefrontProduct>[];
        if (items.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Related Products',
              style: TextStyle(
                color: Color(0xff574335),
                fontFamily: 'Fraunces',
                fontSize: 23,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 218,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(width: 11),
                itemBuilder: (context, index) {
                  final product = items[index];
                  return SizedBox(
                    width: 145,
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ProductDetailsScreen(
                              product: product,
                              storefrontService: storefrontService,
                            ),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(9),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: SizedBox(
                                  width: double.infinity,
                                  child: product.imageUrl == null
                                      ? const Icon(Icons.diamond_outlined)
                                      : ShimmerNetworkImage(
                                          url: product.imageUrl!,
                                          fit: BoxFit.contain,
                                        ),
                                ),
                              ),
                              const SizedBox(height: 7),
                              Text(
                                product.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xff574335),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _PriceRow._price(
                                  product.amount,
                                  product.currencyCode,
                                ),
                                style: const TextStyle(
                                  color: _ProductDetailsScreenState._brown,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DetailsTile extends StatelessWidget {
  const _DetailsTile({
    required this.title,
    required this.body,
    this.htmlBody = '',
    this.richBody = const [],
  });

  final String title;
  final String body;
  final String htmlBody;
  final List<StorefrontRichTextSegment> richBody;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: const Color(0x229d6043)),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 14),
        title: Text(
          title,
          style: const TextStyle(
            color: Color(0xff574335),
            fontFamily: 'Fraunces',
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        children: [
          if (htmlBody.isNotEmpty && richBody.isNotEmpty)
            RichText(
              text: TextSpan(
                style: const TextStyle(
                  color: Color(0xff625b57),
                  fontSize: 14,
                  height: 1.55,
                ),
                children: richBody
                    .map(
                      (segment) => TextSpan(
                        text: segment.text,
                        style: TextStyle(
                          fontWeight: segment.bold
                              ? FontWeight.w700
                              : FontWeight.w400,
                          fontStyle: segment.italic
                              ? FontStyle.italic
                              : FontStyle.normal,
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            )
          else
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                body,
                style: const TextStyle(
                  color: Color(0xff776e68),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProductActions extends StatelessWidget {
  const _ProductActions({
    required this.favorite,
    required this.available,
    required this.onFavorite,
    required this.onAddToCart,
  });

  final bool favorite;
  final bool available;
  final VoidCallback onFavorite;
  final VoidCallback onAddToCart;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 10,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 12),
          child: Row(
            children: [
              OutlinedButton(
                onPressed: onFavorite,
                style: OutlinedButton.styleFrom(
                  shape: const CircleBorder(),
                  side: const BorderSide(color: Color(0xffffb640)),
                  padding: const EdgeInsets.all(12),
                ),
                child: Icon(
                  favorite ? Icons.favorite : Icons.favorite_border,
                  color: const Color(0xffffad2f),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: SizedBox(
                  height: 49,
                  child: FilledButton(
                    onPressed: available ? onAddToCart : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: _ProductDetailsScreenState._brown,
                      disabledBackgroundColor: const Color(0xffbdb5b0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child: Text(
                      available ? 'Add to Cart' : 'Out of Stock',
                      style: const TextStyle(
                        color: Color(0xffffdb91),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
