import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme.dart';

/// Opens Google Maps directions to the venue (works on phone and web).
Uri venueMapsUri(String venue) => Uri.https(
      'www.google.com',
      '/maps/dir/',
      {'api': '1', 'destination': venue},
    );

class DirectionsLink extends StatelessWidget {
  const DirectionsLink({super.key, required this.venue});

  final String venue;

  @override
  Widget build(BuildContext context) {
    if (venue.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => launchUrl(venueMapsUri(venue), mode: LaunchMode.externalApplication),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.directions_outlined, size: 18, color: Brand.accent),
              const SizedBox(width: 6),
              Text('Get directions',
                  style: Brand.body(15, weight: FontWeight.w700, color: Brand.accent)),
            ],
          ),
        ),
      ),
    );
  }
}
