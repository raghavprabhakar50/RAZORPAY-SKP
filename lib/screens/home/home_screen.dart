import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../orders/my_orders_screen.dart';

import '../../data/home_screen_data.dart';
import '../../models/discount_banner.dart';
import '../../models/home_catalog.dart';
import '../../models/home_slide.dart';
import '../../models/storefront_predictive_search_result.dart';
import '../../services/account_store.dart';
import '../../services/shopify_storefront_service.dart';
import '../../utils/navigation.dart';
import '../../widgets/account_avatar.dart';
import '../../widgets/account_drawer.dart';
import '../../widgets/app_shimmer.dart';
import '../../widgets/storefront_bottom_navigation.dart';
import '../cart/cart_screen.dart';
import '../category/categories_screen.dart';
import '../login/login_screen.dart';
import '../login/shopify_login_screen.dart';
import '../product/product_details_screen.dart';
import '../profile/profile_screen.dart';
import '../profile/notification_preferences_screen.dart';
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

  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  late final ShopifyStorefrontService _storefrontService;
  late Future<HomeScreenData> _homeData;
  StorefrontCollection? _selectedPriceCollection;
  Timer? _searchDebounce;
  StorefrontPredictiveSearchResult _searchResults =
      StorefrontPredictiveSearchResult.empty;
  String? _searchError;
  bool _searchLoading = false;
  int _searchRequestId = 0;

  @override
  void initState() {
    super.initState();
    _storefrontService = widget.storefrontService ?? ShopifyStorefrontService();
    _homeData = _loadHome();
    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(_refreshProductFilter);
  }

  Future<HomeScreenData> _loadHome({bool forceRefresh = false}) async {
    final content = await _storefrontService.fetchHomeContent(
      forceRefresh: forceRefresh,
    );
    unawaited(_storefrontService.fetchCollections(forceRefresh: forceRefresh));
    final catalog = content.catalog;
    return HomeScreenData(
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

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    final requestId = ++_searchRequestId;
    final query = _searchController.text.trim();

    if (query.length < 2) {
      if (!mounted) return;
      setState(() {
        _searchLoading = false;
        _searchError = null;
        _searchResults = StorefrontPredictiveSearchResult.empty;
      });
      return;
    }

    setState(() {
      _searchLoading = true;
      _searchError = null;
    });
    _searchDebounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final results = await _storefrontService.predictiveSearch(query);
        await _precacheSearchImages(results);
        if (!mounted || requestId != _searchRequestId) return;
        setState(() {
          _searchResults = results;
          _searchLoading = false;
        });
      } on Object {
        if (!mounted || requestId != _searchRequestId) return;
        setState(() {
          _searchResults = StorefrontPredictiveSearchResult.empty;
          _searchLoading = false;
          _searchError = 'Search could not be loaded. Please try again.';
        });
      }
    });
  }

  Future<void> _precacheSearchImages(
    StorefrontPredictiveSearchResult results,
  ) async {
    if (!mounted) return;
    await Future.wait(
      results.products.map((product) async {
        final imageUrl = product.imageUrl;
        if (imageUrl == null || imageUrl.isEmpty) return;
        await precacheImage(
          NetworkImage(optimizedShopifyImageUrl(imageUrl, maxWidth: 160)),
          context,
          onError: (_, _) {},
        );
      }),
    );
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

  void _openCategories() {
    Navigator.of(context).push(
      instantPageRoute<void>(
        builder: (_) => CategoriesScreen(storefrontService: _storefrontService),
      ),
    );
  }

  void _openWishlist() {
    Navigator.of(context).push(
      instantPageRoute<void>(
        builder: (_) => WishlistScreen(storefrontService: _storefrontService),
      ),
    );
  }

  void _openCart() {
    Navigator.of(context).push(
      instantPageRoute<void>(
        builder: (_) => CartScreen(storefrontService: _storefrontService),
      ),
    );
  }

  Future<bool> _ensureLogin() async {
    if (AccountStore.instance.isAuthenticated) return true;
    final loggedIn = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => const ShopifyLoginScreen(returnToPrevious: true),
      ),
    );
    return loggedIn == true && AccountStore.instance.isAuthenticated;
  }

  Future<void> _openProfile() async {
    if (!await _ensureLogin() || !mounted) return;
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const ProfileScreen()));
  }

  Future<void> _openOrders() async {
    if (!await _ensureLogin() || !mounted) return;
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const MyOrdersScreen()));
  }

  Future<void> _openNotificationPreferences() async {
    if (!await _ensureLogin() || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const NotificationPreferencesScreen(),
      ),
    );
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Logout?'),
        content: const Text('You will need to login again to checkout.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await AccountStore.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  void _openProduct(StorefrontProduct product) {
    _searchFocusNode.unfocus();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProductDetailsScreen(
          product: product,
          storefrontService: _storefrontService,
        ),
      ),
    );
  }

  void _useSearchSuggestion(String suggestion) {
    _searchController.value = TextEditingValue(
      text: suggestion,
      selection: TextSelection.collapsed(offset: suggestion.length),
    );
    _searchFocusNode.requestFocus();
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

  void _openAllProducts() {
    _openCollection(
      const StorefrontCollection(
        id: '',
        handle: 'all-products',
        title: 'All Products',
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
    _searchDebounce?.cancel();
    _searchFocusNode
      ..removeListener(_refreshProductFilter)
      ..dispose();
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Color(0xfff6d18d),
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: const Color(0xfff6d18d),
        drawer: AccountDrawer(
          onHome: () {},
          onProfile: _openProfile,
          onOrders: _openOrders,
          onWishlist: _openWishlist,
          onCart: _openCart,
          onNotificationPreferences: _openNotificationPreferences,
          onLogin: _openProfile,
          onLogout: _logout,
        ),
        body: SafeArea(
          top: true,
          bottom: false,
          child: FutureBuilder<HomeScreenData>(
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
                          padding: const EdgeInsets.fromLTRB(10, 31, 10, 18),
                          child: Column(
                            children: [
                              _HomeHeader(
                                controller: _searchController,
                                focusNode: _searchFocusNode,
                                searchResults: _searchResults,
                                searchLoading: _searchLoading,
                                searchError: _searchError,
                                showResults:
                                    _searchFocusNode.hasFocus &&
                                    _searchController.text.trim().isNotEmpty,
                                onSuggestionTap: _useSearchSuggestion,
                                onProductTap: _openProduct,
                                onMenuTap: () =>
                                    _scaffoldKey.currentState?.openDrawer(),
                                onProfileTap: _openProfile,
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
                            onSeeAll: _openAllProducts,
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
                                onTap: () => _openProduct(products[index]),
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
        ),
        bottomNavigationBar: StorefrontBottomNavigation(
          selectedIndex: 0,
          onCategories: _openCategories,
          onWishlist: _openWishlist,
          onCart: _openCart,
        ),
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
            padding: const EdgeInsets.fromLTRB(10, 31, 10, 18),
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
                child: SingleChildScrollView(
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
          ),
        ],
      ),
    );
  }
}

class _HomeHeader extends StatefulWidget {
  const _HomeHeader({
    required this.controller,
    required this.focusNode,
    required this.searchResults,
    required this.searchLoading,
    required this.showResults,
    required this.onSuggestionTap,
    required this.onProductTap,
    required this.onMenuTap,
    required this.onProfileTap,
    this.searchError,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final StorefrontPredictiveSearchResult searchResults;
  final bool searchLoading;
  final bool showResults;
  final String? searchError;
  final ValueChanged<String> onSuggestionTap;
  final ValueChanged<StorefrontProduct> onProductTap;
  final VoidCallback onMenuTap;
  final VoidCallback onProfileTap;

  @override
  State<_HomeHeader> createState() => _HomeHeaderState();
}

class _HomeHeaderState extends State<_HomeHeader> {
  final _searchFieldKey = GlobalKey();
  OverlayEntry? _searchOverlay;

  @override
  void initState() {
    super.initState();
    _scheduleOverlaySync();
  }

  @override
  void didUpdateWidget(covariant _HomeHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleOverlaySync();
  }

  void _scheduleOverlaySync() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.showResults) {
        if (_searchOverlay == null) {
          _searchOverlay = OverlayEntry(builder: _buildSearchOverlay);
          Overlay.of(context).insert(_searchOverlay!);
        } else {
          _searchOverlay!.markNeedsBuild();
        }
      } else {
        _removeSearchOverlay();
      }
    });
  }

  Widget _buildSearchOverlay(BuildContext context) {
    final renderBox =
        _searchFieldKey.currentContext?.findRenderObject() as RenderBox?;
    final mediaQuery = MediaQuery.of(context);
    final fieldLeft = renderBox?.localToGlobal(Offset.zero).dx ?? 10.0;
    final fieldBottom = renderBox == null
        ? 150.0
        : renderBox.localToGlobal(Offset.zero).dy + renderBox.size.height;
    final horizontalMargin = fieldLeft.clamp(0.0, mediaQuery.size.width / 4);
    return Positioned(
      left: horizontalMargin,
      right: horizontalMargin,
      top: fieldBottom + 10,
      bottom: mediaQuery.viewInsets.bottom,
      child: TextFieldTapRegion(
        child: Material(
          type: MaterialType.transparency,
          child: _PredictiveSearchPanel(
            query: widget.controller.text.trim(),
            results: widget.searchResults,
            loading: widget.searchLoading,
            error: widget.searchError,
            onSuggestionTap: widget.onSuggestionTap,
            onProductTap: widget.onProductTap,
          ),
        ),
      ),
    );
  }

  void _removeSearchOverlay() {
    _searchOverlay?.remove();
    _searchOverlay = null;
  }

  @override
  void dispose() {
    _removeSearchOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Material(
              color: Colors.white,
              shape: const CircleBorder(),
              elevation: 4,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: widget.onMenuTap,
                child: const SizedBox(
                  width: 47,
                  height: 47,
                  child: Icon(
                    Icons.menu_rounded,
                    size: 31,
                    color: Color(0xff514a45),
                  ),
                ),
              ),
            ),
            const Spacer(),
            AccountAvatar(radius: 23.5, onTap: widget.onProfileTap),
          ],
        ),
        const SizedBox(height: 18),
        SizedBox(
          key: _searchFieldKey,
          width: double.infinity,
          child: TextField(
            controller: widget.controller,
            focusNode: widget.focusNode,
            textInputAction: TextInputAction.search,
            autocorrect: false,
            enableSuggestions: true,
            onTapOutside: (_) => widget.focusNode.unfocus(),
            decoration: InputDecoration(
              hintText: 'Search',
              hintStyle: const TextStyle(
                color: Color(0xffcdbdb4),
                fontSize: 13,
              ),
              suffixIconConstraints: const BoxConstraints(
                minWidth: 49,
                minHeight: 47,
              ),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.controller.text.isNotEmpty)
                    IconButton(
                      tooltip: 'Clear search',
                      onPressed: widget.controller.clear,
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Color(0xff85766e),
                        size: 20,
                      ),
                    ),
                  Container(
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
                ],
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
        ),
      ],
    );
  }
}

class _PredictiveSearchPanel extends StatelessWidget {
  const _PredictiveSearchPanel({
    required this.query,
    required this.results,
    required this.loading,
    required this.onSuggestionTap,
    required this.onProductTap,
    this.error,
  });

  final String query;
  final StorefrontPredictiveSearchResult results;
  final bool loading;
  final String? error;
  final ValueChanged<String> onSuggestionTap;
  final ValueChanged<StorefrontProduct> onProductTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(15, 15, 15, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: SingleChildScrollView(child: _content(context)),
    );
  }

  Widget _content(BuildContext context) {
    if (query.length < 2) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 15),
        child: Text(
          'Type at least 2 letters to search',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xff8d817b), fontSize: 13),
        ),
      );
    }

    if (loading) {
      return const AppShimmer(
        child: Column(
          children: [
            ShimmerBox(height: 18, borderRadius: 5),
            SizedBox(height: 12),
            ShimmerBox(height: 58, borderRadius: 9),
            SizedBox(height: 8),
            ShimmerBox(height: 58, borderRadius: 9),
          ],
        ),
      );
    }

    if (error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 15),
        child: Text(
          error!,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xff9d6043), fontSize: 13),
        ),
      );
    }

    if (results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 15),
        child: Text(
          'No results found for "$query"',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xff8d817b), fontSize: 13),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (results.suggestions.isNotEmpty) ...[
          const _SearchSectionTitle('Suggestions'),
          const SizedBox(height: 7),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: results.suggestions
                .map(
                  (suggestion) => ActionChip(
                    label: Text(suggestion),
                    onPressed: () => onSuggestionTap(suggestion),
                    backgroundColor: const Color(0xfffff7e9),
                    side: const BorderSide(color: Color(0xffefd9b5)),
                    labelStyle: const TextStyle(
                      color: Color(0xff5c463b),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: 14),
        ],
        if (results.products.isNotEmpty) ...[
          const _SearchSectionTitle('Products'),
          const SizedBox(height: 5),
          for (final product in results.products)
            _SearchProductTile(
              product: product,
              onTap: () => onProductTap(product),
            ),
        ],
      ],
    );
  }
}

class _SearchSectionTitle extends StatelessWidget {
  const _SearchSectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: Color(0xff8d817b),
            fontSize: 10,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(child: Divider(height: 1, color: Color(0xffeee6e1))),
      ],
    );
  }
}

class _SearchProductTile extends StatelessWidget {
  const _SearchProductTile({required this.product, required this.onTap});

  final StorefrontProduct product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 50,
                height: 50,
                child: _NetworkImage(
                  url: product.imageUrl,
                  fit: BoxFit.cover,
                  maxWidth: 160,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xff3f3029),
                      fontSize: 13,
                      height: 1.25,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatSearchPrice(product),
                    style: const TextStyle(
                      color: Color(0xffa86143),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xffb98c72),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  static String _formatSearchPrice(StorefrontProduct product) {
    final amount = product.amount.round().toString();
    return product.currencyCode == 'INR'
        ? 'Rs $amount'
        : '${product.currencyCode} $amount';
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
  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    _startAutoRotation();
  }

  void _startAutoRotation() {
    _timer?.cancel();
    if (widget.banners.length < 2) return;
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_controller.hasClients || widget.banners.length < 2) {
        return;
      }
      final next = (_page + 1) % widget.banners.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void didUpdateWidget(covariant _DiscountCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.banners.length != widget.banners.length) {
      _page = 0;
      _startAutoRotation();
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
  const _NetworkImage({
    required this.url,
    required this.fit,
    this.maxWidth = 1200,
  });

  final String? url;
  final BoxFit fit;
  final int maxWidth;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return const Icon(Icons.diamond_outlined, color: Color(0xffb99578));
    }
    return ShimmerNetworkImage(
      url: url!,
      fit: fit,
      maxWidth: maxWidth,
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
