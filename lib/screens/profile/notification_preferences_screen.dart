import 'package:flutter/material.dart';

import '../../services/push_notification_service.dart';

class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  State<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends State<NotificationPreferencesScreen> {
  static const _brown = Color(0xff9d6043);
  Map<String, bool> _values = const {};
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final values = await PushNotificationService.instance
        .notificationPreferences();
    if (!mounted) return;
    setState(() {
      _values = values;
      _loading = false;
    });
  }

  Future<void> _set(String key, bool value) async {
    final updated = {..._values, key: value};
    setState(() {
      _values = updated;
      _saving = true;
    });
    await PushNotificationService.instance.saveNotificationPreferences(updated);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Notification preferences saved.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfffdfcfb),
      appBar: AppBar(
        backgroundColor: const Color(0xfffdfcfb),
        foregroundColor: const Color(0xff5b4336),
        title: const Text('Notifications'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _brown))
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
              children: [
                const Text(
                  'Choose the updates you want to receive.',
                  style: TextStyle(color: Color(0xff75685f), fontSize: 14),
                ),
                const SizedBox(height: 16),
                _preference(
                  keyName: 'transactional_enabled',
                  title: 'Orders and payments',
                  subtitle: 'Payment, confirmation, shipping, delivery, cancellation and refunds',
                  icon: Icons.receipt_long_outlined,
                ),
                _preference(
                  keyName: 'product_updates_enabled',
                  title: 'Wishlist product updates',
                  subtitle: 'Back in stock and price drops for your wishlist',
                  icon: Icons.favorite_border_rounded,
                ),
                _preference(
                  keyName: 'offers_enabled',
                  title: 'Offers and discounts',
                  subtitle: 'New sales and discount announcements',
                  icon: Icons.local_offer_outlined,
                ),
                _preference(
                  keyName: 'cart_reminders_enabled',
                  title: 'Cart reminders',
                  subtitle: 'A reminder if items stay in your cart. Off until you enable it.',
                  icon: Icons.shopping_bag_outlined,
                ),
                if (_saving)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: LinearProgressIndicator(color: _brown),
                  ),
              ],
            ),
    );
  }

  Widget _preference({
    required String keyName,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xffeadfd7)),
      ),
      child: SwitchListTile.adaptive(
        activeTrackColor: _brown,
        secondary: Icon(icon, color: _brown),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        value: _values[keyName] ?? false,
        onChanged: _saving ? null : (value) => _set(keyName, value),
      ),
    );
  }
}
