import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/discount_banner.dart';
import '../../models/home_catalog.dart';
import '../../models/home_slide.dart';
import '../../services/shopify_storefront_service.dart';
import '../../widgets/app_shimmer.dart';
import '../../widgets/storefront_bottom_navigation.dart';
import '../cart/cart_screen.dart';
import '../category/categories_screen.dart';
import '../product/product_details_screen.dart';
import '../wishlist/wishlist_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({this.guest = false, this.storefrontService, super.key});

  final bool guest;
  final ShopifyStorefrontService? storefrontService;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _brown = Color(0xff9d6043);

  final _searchController = TextEditingController();
  late final ShopifyStorefrontService _storefrontService;
  late Future<_HomeData> _homeData;
  StorefrontCollection? _selectedPriceCollection;

  @override
  void initState() {
    super.initState();
    _storefrontService = widget.storefrontService ?? ShopifyStorefrontService();
    _homeData = _loadHome();
    _searchController.addListener(_refreshProductFilter);
  }

  Future<_HomeData> _loadHome({bool forceRefresh = false}) async {
    final content = await _storefrontService.fetchHomeContent(
      forceRefresh: forceRefresh,
    );
    unawaited(_storefrontService.fetchCollections(forceRefresh: forceRefresh));
    final catalog = content.catalog;
    return _HomeData(
      slides: content.slides,
      collections: catalog.collections,
      products: catalog.products,
      priceCollections: catalog.priceCollections,
      discountBanners: content.discountBanners,
    );
  }

  Future<void> _reload() async {
    final nextLoad = _loadHome(forceRefresh: true);
    setState(() {
      _homeData = nextLoad;
    });
    await nextLoad;
  }

  void _refreshProductFilter() {
    if (mounted) setState(() {});
  }

  List<StorefrontProduct> _visibleProducts(List<StorefrontProduct> products) {
    final search = _searchController.text.trim().toLowerCase();
    return products
        .where((product) {
          final matchesSearch =
              search.isEmpty || product.title.toLowerCase().contains(search);
          return matchesSearch;
        })
        .toList(growable: false);
  }

  void _showTarget(String target) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(target)));
  }

  void _openCategories() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CategoriesScreen(storefrontService: _storefrontService),
      ),
    );
  }

  void _openWishlist() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WishlistScreen(storefrontService: _storefrontService),
      ),
    );
  }

  void _openCart() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CartScreen(storefrontService: _storefrontService),
      ),
    );
  }

  void _openCollection(StorefrontCollection collection) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CollectionProductsScreen(
          collection: collection,
          storefrontService: _storefrontService,
        ),
      ),
    );
  }

  void _openSlideCollection(HomeSlide slide) {
    final handle = slide.collectionHandle?.trim();
    if (handle == null || handle.isEmpty) {
      _openCategories();
      return;
    }

    _openCollection(
      StorefrontCollection(
        id: slide.collectionId ?? '',
        handle: handle,
        title: slide.collectionTitle?.trim().isNotEmpty == true
            ? slide.collectionTitle!.trim()
            : 'Products',
      ),
    );
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_refreshProductFilter)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff6cf88),
      body: FutureBuilder<_HomeData>(
        future: _homeData,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _HomeLoadingShimmer();
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return SafeArea(child: _HomeError(onRetry: _reload));
          }
          final data = snapshot.requireData;
          final products = _visibleProducts(data.products);
          final avatarUrl = data.slides.isEmpty
              ? null
              : data.slides.first.imageUrl;
          return RefreshIndicator(
            color: _brown,
            onRefresh: _reload,
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xfff6d18d), Color(0xfff4c977)],
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(17, 25, 17, 18),
                      child: Column(
                        children: [
                          _HomeHeader(
                            controller: _searchController,
                            avatarUrl: avatarUrl,
                          ),
                          const SizedBox(height: 19),
                          if (data.slides.isNotEmpty)
                            _HeroCarousel(
                              slides: data.slides,
                              onOpen: _openSlideCollection,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(17, 18, 17, 26),
                  decoration: const BoxDecoration(
                    color: Color(0xfffdfcfb),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(30),
                    ),
                  ),
                  child: Column(
                    children: [
                      _SectionHeader(
                        title: 'Categories',
                        onSeeAll: _openCategories,
                      ),
                      const SizedBox(height: 9),
                      _CategoryList(
                        collections: data.collections,
                        onAllTap: _openCategories,
                        onTap: _openCollection,
                      ),
                      if (data.priceCollections.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        const _SectionHeader(title: 'Shop By Price'),
                        const SizedBox(height: 11),
                        _PriceSelector(
                          collections: data.priceCollections,
                          selected: _selectedPriceCollection,
                          onSelected: (collection) {
                            setState(() {
                              _selectedPriceCollection = collection;
                            });
                            _openCollection(collection);
                          },
                        ),
                      ],
                      if (data.discountBanners.isNotEmpty) ...[
                        const SizedBox(height: 47),
                        _DiscountCarousel(banners: data.discountBanners),
                        const SizedBox(height: 34),
                      ] else
                        const SizedBox(height: 34),
                      _SectionHeader(
                        title: 'Latest Arrivals',
                        onSeeAll: () => _showTarget('All products'),
                      ),
                      const SizedBox(height: 12),
                      if (products.isEmpty)
                        const _EmptyProducts()
                      else
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: products.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 14,
                                mainAxisSpacing: 12,
                                childAspectRatio: .75,
                              ),
                          itemBuilder: (context, index) => _ProductCard(
                            product: products[index],
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => ProductDetailsScreen(
                                  product: products[index],
                                  storefrontService: _storefrontService,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: StorefrontBottomNavigation(
        selectedIndex: 0,
        onCategories: _openCategories,
        onWishlist: _openWishlist,
        onCart: _openCart,
      ),
    );
  }
}

class _HomeLoadingShimmer extends StatelessWidget {
  const _HomeLoadingShimmer();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(17, 25, 17, 18),
            child: AppShimmer(
              child: Column(
                children: [
                  const Row(
                    children: [
                      ShimmerBox(width: 48, height: 48, borderRadius: 24),
                      Spacer(),
                      ShimmerBox(width: 48, height: 48, borderRadius: 24),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const ShimmerBox(height: 50, borderRadius: 25),
                  const SizedBox(height: 18),
                  const ShimmerBox(height: 190, borderRadius: 12),
                ],
              ),
            ),
          ),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(17, 22, 17, 20),
              decoration: const BoxDecoration(
                color: Color(0xfffdfcfb),
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: AppShimmer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ShimmerBox(width: 145, height: 27),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 112,
                      child: Row(
                        children: List.generate(
                          4,
                          (index) => const Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(right: 10),
                              child: ShimmerBox(borderRadius: 9),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    const ShimmerBox(width: 175, height: 27),
                    const SizedBox(height: 15),
                    const Row(
                      children: [
                        Expanded(child: ShimmerBox(height: 48)),
                        SizedBox(width: 12),
                        Expanded(child: ShimmerBox(height: 48)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Row(
                      children: [
                        Expanded(child: ShimmerBox(height: 48)),
                        SizedBox(width: 12),
                        Expanded(child: ShimmerBox(height: 48)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeData {
  const _HomeData({
    required this.slides,
    required this.collections,
    required this.products,
    required this.priceCollections,
    required this.discountBanners,
  });

  final List<HomeSlide> slides;
  final List<StorefrontCollection> collections;
  final List<StorefrontProduct> products;
  final List<StorefrontCollection> priceCollections;
  final List<DiscountBanner> discountBanners;
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.controller, this.avatarUrl});

  final TextEditingController controller;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 47,
              height: 47,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x24000000),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.menu_rounded,
                size: 31,
                color: Color(0xff514a45),
              ),
            ),
            const Spacer(),
            Container(
              width: 47,
              height: 47,
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: ClipOval(
                child: _NetworkImage(url: avatarUrl, fit: BoxFit.cover),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        TextField(
          controller: controller,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search',
            hintStyle: const TextStyle(color: Color(0xffcdbdb4), fontSize: 13),
            suffixIconConstraints: const BoxConstraints(
              minWidth: 47,
              minHeight: 47,
            ),
            suffixIcon: Container(
              width: 43,
              height: 43,
              margin: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Color(0xfff4cc82),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_rounded,
                color: Color(0xff855b48),
                size: 29,
              ),
            ),
            filled: true,
            fillColor: Colors.white,
            isDense: true,
            contentPadding: const EdgeInsets.fromLTRB(15, 15, 5, 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroCarousel extends StatefulWidget {
  const _HeroCarousel({required this.slides, required this.onOpen});

  final List<HomeSlide> slides;
  final ValueChanged<HomeSlide> onOpen;

  @override
  State<_HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<_HeroCarousel> {
  final _controller = PageController();
  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    if (widget.slides.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 4), (_) {
        if (!_controller.hasClients) return;
        final next = (_page + 1) % widget.slides.length;
        _controller.animateToPage(
          next,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeInOutCubic,
        );
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 203,
      child: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.slides.length,
            onPageChanged: (page) => setState(() => _page = page),
            itemBuilder: (context, index) {
              final slide = widget.slides[index];
              return ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ShimmerNetworkImage(
                      url: slide.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const ColoredBox(
                        color: Color(0xffd9c2b2),
                        child: Icon(Icons.image_not_supported_outlined),
                      ),
                    ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xcc241b18), Color(0x10241b18)],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(19, 15, 14, 25),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: .60,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                slide.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'Fraunces',
                                  fontSize: 27,
                                  height: 1.08,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 9),
                              Text(
                                slide.subtitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  height: 1.35,
                                ),
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                height: 45,
                                child: FilledButton(
                                  onPressed: () => widget.onOpen(slide),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xfff3ca7d),
                                    foregroundColor: const Color(0xff654835),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 19,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(9),
                                    ),
                                  ),
                                  child: Text(
                                    slide.buttonLabel,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          Positioned(
            bottom: 7,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.slides.length, (index) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: index == _page ? 18 : 5,
                  height: 5,
                  margin: const EdgeInsets.symmetric(horizontal: 2.5),
                  decoration: BoxDecoration(
                    color: index == _page
                        ? const Color(0xfff3ca7d)
                        : Colors.white70,
                    borderRadius: BorderRadius.circular(20),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.onSeeAll});

  final String title;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xff574335),
            fontFamily: 'Fraunces',
            fontSize: 27,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        if (onSeeAll != null)
          TextButton(
            onPressed: onSeeAll,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xffad6b4a),
              padding: EdgeInsets.zero,
              minimumSize: const Size(42, 28),
              visualDensity: VisualDensity.compact,
            ),
            child: const Text('See All', style: TextStyle(fontSize: 10)),
          ),
      ],
    );
  }
}

class _CategoryList extends StatelessWidget {
  const _CategoryList({
    required this.collections,
    required this.onAllTap,
    required this.onTap,
  });

  final List<StorefrontCollection> collections;
  final VoidCallback onAllTap;
  final ValueChanged<StorefrontCollection> onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 124,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: collections.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 13),
        itemBuilder: (context, index) {
          if (index == 0) {
            return InkWell(
              onTap: onAllTap,
              borderRadius: BorderRadius.circular(9),
              child: Container(
                width: 89,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xfff3ca7d),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Text(
                  'All',
                  style: TextStyle(
                    color: Color(0xff7d4d39),
                    fontFamily: 'Fraunces',
                    fontSize: 27,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }
          final collection = collections[index - 1];
          return InkWell(
            onTap: () => onTap(collection),
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 88,
              child: Column(
                children: [
                  Expanded(
                    child: Container(
                      width: 88,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(9),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x16000000),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: _NetworkImage(
                        url: collection.imageUrl,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    collection.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xff6d5548),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PriceSelector extends StatelessWidget {
  const _PriceSelector({
    required this.collections,
    required this.selected,
    required this.onSelected,
  });

  final List<StorefrontCollection> collections;
  final StorefrontCollection? selected;
  final ValueChanged<StorefrontCollection> onSelected;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: collections.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 18,
        childAspectRatio: 3.55,
      ),
      itemBuilder: (context, index) {
        final collection = collections[index];
        final active = collection == selected;
        return InkWell(
          onTap: () => onSelected(collection),
          borderRadius: BorderRadius.circular(9),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? const Color(0xff9d6043) : const Color(0xfff3ca7d),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              collection.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: active ? Colors.white : const Color(0xff9a6048),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DiscountCarousel extends StatefulWidget {
  const _DiscountCarousel({required this.banners});

  final List<DiscountBanner> banners;

  @override
  State<_DiscountCarousel> createState() => _DiscountCarouselState();
}

class _DiscountCarouselState extends State<_DiscountCarousel> {
  late final PageController _controller;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 210,
      child: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.banners.length,
            onPageChanged: (page) => setState(() => _page = page),
            itemBuilder: (context, index) {
              final banner = widget.banners[index];
              return Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: widget.banners.length > 1 ? 4 : 0,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _NetworkImage(url: banner.imageUrl, fit: BoxFit.cover),
                      if (banner.showOverlay) ...[
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xde1b1615), Color(0x251b1615)],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(19, 16, 15, 30),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: .64,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    banner.heading,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontFamily: 'Fraunces',
                                      fontSize: 28,
                                      height: .98,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (banner.subtitle.isNotEmpty) ...[
                                    const SizedBox(height: 9),
                                    Text(
                                      banner.subtitle,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Color(0xffffd67f),
                                        fontSize: 14,
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
          if (widget.banners.length > 1)
            Positioned(
              left: 20,
              bottom: 14,
              child: Row(
                children: List.generate(widget.banners.length, (index) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: index == _page ? 22 : 9,
                    height: 9,
                    margin: const EdgeInsets.only(right: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xffffd67f),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product, required this.onTap});

  final StorefrontProduct product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 3,
      shadowColor: const Color(0x22000000),
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 11, 14, 13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SizedBox(
                  width: double.infinity,
                  child: _NetworkImage(
                    url: product.imageUrl,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 9),
              Text(
                product.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xff382d27),
                  fontSize: 15,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                product.productType ?? 'All products',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xff8d817b), fontSize: 10),
              ),
              const SizedBox(height: 8),
              Text(
                _formatPrice(product),
                style: const TextStyle(
                  color: Color(0xff9d4f30),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatPrice(StorefrontProduct product) {
    final amount = product.amount.round().toString();
    return product.currencyCode == 'INR'
        ? 'Rs $amount'
        : '${product.currencyCode} $amount';
  }
}

class _NetworkImage extends StatelessWidget {
  const _NetworkImage({required this.url, required this.fit});

  final String? url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return const Icon(Icons.diamond_outlined, color: Color(0xffb99578));
    }
    return ShimmerNetworkImage(
      url: url!,
      fit: fit,
      errorBuilder: (_, _, _) => const Icon(
        Icons.image_not_supported_outlined,
        color: Color(0xffb99578),
      ),
    );
  }
}

class _EmptyProducts extends StatelessWidget {
  const _EmptyProducts();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 45),
      child: Center(child: Text('No products found')),
    );
  }
}

class _HomeError extends StatelessWidget {
  const _HomeError({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            color: Color(0xff9d6043),
            size: 42,
          ),
          const SizedBox(height: 12),
          const Text('Could not load the store'),
          const SizedBox(height: 10),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
