import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme.dart';

bool isWide(BuildContext context) => MediaQuery.sizeOf(context).width >= 720;

Future<void> openUrl(String url) async {
  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}

void snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 5),
    ));
}

String errorText(Object e) => e.toString().replaceFirst('Exception: ', '');

/// A scrolling page that stays readable on phones, tablets and the web.
class PageScroll extends StatelessWidget {
  const PageScroll({
    super.key,
    required this.title,
    this.subtitle,
    required this.children,
    this.onRefresh,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final list = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      children: [
        Text(title, style: Brand.display(34, weight: FontWeight.w700, height: 1.1)),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(subtitle!, style: Brand.body(16, height: 1.5)),
          ),
        const SizedBox(height: 20),
        ...children,
      ],
    );
    final content = Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: list,
      ),
    );
    return SafeArea(
      bottom: false,
      child: onRefresh == null
          ? content
          : RefreshIndicator(onRefresh: onRefresh!, child: content),
    );
  }
}

class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.color = Brand.card,
    this.padding = const EdgeInsets.all(24),
    this.borderColor = Brand.cardLine,
  });

  final Widget child;
  final Color color;
  final EdgeInsets padding;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
  }
}

class Tag extends StatelessWidget {
  const Tag(this.text, {super.key, this.bg = Brand.blush, this.fg = const Color(0xFF8F1747)});

  final String text;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: Brand.body(13, weight: FontWeight.w700, color: fg)),
    );
  }
}

/// Lays children out in as many columns as fit, so cards use wide screens well.
class ResponsiveWrap extends StatelessWidget {
  const ResponsiveWrap({
    super.key,
    required this.children,
    this.minItemWidth = 300,
    this.spacing = 16,
  });

  final List<Widget> children;
  final double minItemWidth;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final maxW = c.maxWidth;
      var cols = ((maxW + spacing) / (minItemWidth + spacing)).floor();
      if (cols < 1) cols = 1;
      final w = (maxW - spacing * (cols - 1)) / cols;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [for (final c in children) SizedBox(width: w, child: c)],
      );
    });
  }
}

class PerkRow extends StatelessWidget {
  const PerkRow(this.text, {super.key, this.color = Brand.inkSoft});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.check_circle, size: 18, color: Brand.accent),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: Brand.body(15, color: color, height: 1.4))),
        ],
      ),
    );
  }
}
