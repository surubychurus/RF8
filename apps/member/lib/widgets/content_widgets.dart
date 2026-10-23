import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/models.dart';
import '../screens/notifications_screen.dart';
import '../services/member_controller.dart';
import '../theme/brand.dart';
import 'common.dart';

Future<void> openLink(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    if (context.mounted) showMessage(context, 'No se pudo abrir el enlace', error: true);
  }
}

/// Banner superior con los anuncios que carga el dueño. Pasa solo cada 6 s.
class BannerCarousel extends StatefulWidget {
  const BannerCarousel({super.key});

  @override
  State<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<BannerCarousel> {
  final _page = PageController();
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 6), (_) {
      final count = context.read<MemberController>().banners.length;
      if (count < 2 || !_page.hasClients) return;
      _page.animateToPage((_index + 1) % count, duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final banners = context.watch<MemberController>().banners;
    if (banners.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        SizedBox(
          height: 132,
          child: PageView.builder(
            controller: _page,
            itemCount: banners.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: _BannerCard(item: banners[i]),
            ),
          ),
        ),
        if (banners.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < banners.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _index ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == _index ? Brand.primary : Brand.outline,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({required this.item});

  final BannerItem item;

  @override
  Widget build(BuildContext context) {
    final hasImage = item.imageUrl != null;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Material(
        color: Brand.surfaceHigh,
        child: InkWell(
          onTap: item.linkUrl == null ? null : () => openLink(context, item.linkUrl!),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasImage)
                Image.network(item.imageUrl!, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox()),
              if (hasImage)
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Color(0xCC000000), Color(0x00000000)],
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.white)),
                    if (item.body != null)
                      Text(item.body!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Campana con la cantidad de notificaciones sin leer.
class NotificationsButton extends StatelessWidget {
  const NotificationsButton({super.key});

  @override
  Widget build(BuildContext context) {
    final unread = context.watch<MemberController>().unreadCount;
    return IconButton(
      tooltip: 'Notificaciones',
      onPressed: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: context.read<MemberController>(),
          child: const NotificationsScreen(),
        ),
      )),
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text('$unread'),
        backgroundColor: Brand.primary,
        child: Icon(unread > 0 ? Icons.notifications : Icons.notifications_none),
      ),
    );
  }
}
