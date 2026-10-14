import 'dart:io';

import 'package:flutter/material.dart';

import '../services/account_store.dart';

class AccountAvatar extends StatelessWidget {
  const AccountAvatar({this.radius = 22, this.onTap, super.key});

  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AccountStore.instance,
      builder: (context, _) {
        final account = AccountStore.instance;
        final profile = account.profile;
        ImageProvider<Object>? image;
        final localPath = profile?.localImagePath;
        if (localPath != null && File(localPath).existsSync()) {
          image = FileImage(File(localPath));
        } else if (profile?.imageUrl?.isNotEmpty == true) {
          image = NetworkImage(profile!.imageUrl!);
        }

        return Semantics(
          button: onTap != null,
          label: account.isAuthenticated ? 'Open profile' : 'Login',
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: CircleAvatar(
              radius: radius,
              backgroundColor: Colors.white,
              child: CircleAvatar(
                radius: radius - 2,
                foregroundImage: image,
                backgroundColor: const Color(0xffffe5b8),
                child: image == null
                    ? Icon(
                        account.isAuthenticated
                            ? Icons.person_rounded
                            : Icons.person_outline_rounded,
                        size: radius,
                        color: const Color(0xff8f5c43),
                      )
                    : null,
              ),
            ),
          ),
        );
      },
    );
  }
}
