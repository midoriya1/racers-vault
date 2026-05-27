import 'dart:io';

import 'package:flutter/material.dart';

import '../design/rv_colors.dart';

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.username,
    this.avatarUrl,
    this.localPath,
    this.radius = 28,
    this.backgroundColor = RvColors.crimson,
  });

  final String username;
  final String? avatarUrl;
  final String? localPath;
  final double radius;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final localPath = this.localPath;
    final avatarUrl = this.avatarUrl;

    ImageProvider? image;
    if (localPath != null && localPath.isNotEmpty) {
      image = FileImage(File(localPath));
    } else if (avatarUrl != null && avatarUrl.isNotEmpty) {
      image = NetworkImage(avatarUrl);
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      backgroundImage: image,
      child: image == null
          ? Text(
              username.trim().isEmpty
                  ? '?'
                  : username.characters.first.toUpperCase(),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: radius * 0.82,
              ),
            )
          : null,
    );
  }
}
