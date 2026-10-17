import 'package:flutter/material.dart';

import '../services/account_store.dart';
import 'account_avatar.dart';

class AccountDrawer extends StatelessWidget {
  const AccountDrawer({
    required this.onHome,
    required this.onProfile,
    required this.onOrders,
    required this.onWishlist,
    required this.onCart,
    required this.onLogin,
    required this.onLogout,
    super.key,
  });

  final VoidCallback onHome;
  final VoidCallback onProfile;
  final VoidCallback onOrders;
  final VoidCallback onWishlist;
  final VoidCallback onCart;
  final VoidCallback onLogin;
  final VoidCallback onLogout;

  void _select(BuildContext context, VoidCallback action) {
    Navigator.of(context).pop();
    action();
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xfffdfcfb),
      child: SafeArea(
        child: AnimatedBuilder(
          animation: AccountStore.instance,
          builder: (context, _) {
            final account = AccountStore.instance;
            final profile = account.profile;
            return Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(22, 25, 18, 23),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xffffdf9d), Color(0xfff4c36e)],
                    ),
                  ),
                  child: Row(
                    children: [
                      AccountAvatar(
                        radius: 34,
                        onTap: () => _select(
                          context,
                          account.isAuthenticated ? onProfile : onLogin,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              account.isAuthenticated
                                  ? profile?.displayName ?? 'Customer'
                                  : 'Welcome, Guest',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xff654331),
                                fontFamily: 'Fraunces',
                                fontSize: 19,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              account.isAuthenticated
                                  ? profile?.email ?? ''
                                  : 'Login to manage your account',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xff785f50),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _DrawerTile(
                  icon: Icons.home_outlined,
                  label: 'Home',
                  onTap: () => _select(context, onHome),
                ),
                _DrawerTile(
                  icon: Icons.person_outline_rounded,
                  label: account.isAuthenticated ? 'My Profile' : 'Login',
                  onTap: () => _select(
                    context,
                    account.isAuthenticated ? onProfile : onLogin,
                  ),
                ),
                _DrawerTile(
                  icon: Icons.receipt_long_outlined,
                  label: 'My Orders',
                  onTap: () => _select(context, onOrders),
                ),
                _DrawerTile(
                  icon: Icons.favorite_border_rounded,
                  label: 'Wishlist',
                  onTap: () => _select(context, onWishlist),
                ),
                _DrawerTile(
                  icon: Icons.shopping_cart_outlined,
                  label: 'Cart',
                  onTap: () => _select(context, onCart),
                ),
                const Spacer(),
                if (account.isAuthenticated) ...[
                  const Divider(height: 1),
                  _DrawerTile(
                    icon: Icons.logout_rounded,
                    label: 'Logout',
                    color: const Color(0xffb3483f),
                    onTap: () => _select(context, onLogout),
                  ),
                ],
                const SizedBox(height: 14),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  const _DrawerTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = const Color(0xff5b514b),
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 22),
      leading: Icon(icon, color: color),
      title: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: Icon(Icons.chevron_right_rounded, color: color, size: 21),
      onTap: onTap,
    );
  }
}
