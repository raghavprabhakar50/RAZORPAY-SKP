import '../models/discount_banner.dart';
import '../models/home_catalog.dart';
import '../models/home_slide.dart';

class HomeScreenData {
  const HomeScreenData({
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
