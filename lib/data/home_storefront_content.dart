import '../models/discount_banner.dart';
import '../models/home_slide.dart';
import 'home_catalog_data.dart';

class HomeStorefrontContent {
  const HomeStorefrontContent({
    required this.slides,
    required this.catalog,
    required this.discountBanners,
  });

  final List<HomeSlide> slides;
  final HomeCatalogData catalog;
  final List<DiscountBanner> discountBanners;
}
