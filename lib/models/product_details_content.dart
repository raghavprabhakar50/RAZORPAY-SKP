class PurchaseBenefit {
  const PurchaseBenefit({required this.asset, required this.label});

  final String asset;
  final String label;
}

class GiftCardOption {
  const GiftCardOption({required this.name, this.imageUrl});

  final String name;
  final String? imageUrl;
}
