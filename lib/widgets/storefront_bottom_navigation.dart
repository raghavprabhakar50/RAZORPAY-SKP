import 'package:flutter/material.dart';

import '../services/shopping_store.dart';

class StorefrontBottomNavigation extends StatelessWidget {
  const StorefrontBottomNavigation({
    required this.selectedIndex,
    this.onHome,
    this.onCategories,
    this.onWishlist,
    this.onCart,
    super.key,
  });

  final int selectedIndex;
  final VoidCallback? onHome;
  final VoidCallback? onCategories;
  final VoidCallback? onWishlist;
  final VoidCallback? onCart;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 12,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 76,
          child: AnimatedBuilder(
            animation: ShoppingStore.instance,
            builder: (context, _) {
              final store = ShoppingStore.instance;
              return Row(
                children: [
                  Expanded(
                    child: _NavItem(
                      icon: Icons.home_rounded,
                      label: 'Home',
                      selected: selectedIndex == 0,
                      onTap: onHome,
                    ),
                  ),
                  Expanded(
                    child: _NavItem(
                      icon: Icons.grid_view_rounded,
                      label: 'Categories',
                      selected: selectedIndex == 1,
                      onTap: onCategories,
                    ),
                  ),
                  Expanded(
                    child: _NavItem(
                      icon: selectedIndex == 2
                          ? Icons.favorite
                          : Icons.favorite_border,
                      label: 'Wishlist',
                      selected: selectedIndex == 2,
                      badgeCount: store.wishlistCount,
                      onTap: onWishlist,
                    ),
                  ),
                  Expanded(
                    child: _NavItem(
                      icon: selectedIndex == 3
                          ? Icons.shopping_cart
                          : Icons.shopping_cart_outlined,
                      label: 'Cart',
                      selected: selectedIndex == 3,
                      badgeCount: store.cartCount,
                      onTap: onCart,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final int badgeCount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xffa66042) : const Color(0xff554f49);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, color: color, size: 27),
                if (badgeCount > 0)
                  Positioned(
                    right: -11,
                    top: -8,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 18),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xffa66042),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Text(
                        badgeCount > 99 ? '99+' : '$badgeCount',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (selected) ...[
              const SizedBox(height: 3),
              Text(label, style: TextStyle(color: color, fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }
}
