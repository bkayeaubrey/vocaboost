import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Shows a beautiful badge unlock notification
class BadgeNotification {
  static void show(BuildContext context, Map<String, dynamic> badge) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;
    
    overlayEntry = OverlayEntry(
      builder: (context) => _BadgeNotificationWidget(
        badge: badge,
        onDismiss: () => overlayEntry.remove(),
      ),
    );
    
    overlay.insert(overlayEntry);
  }
  
  /// Show multiple badges unlocked
  static void showMultiple(BuildContext context, List<Map<String, dynamic>> badges) {
    if (badges.isEmpty) return;
    
    for (int i = 0; i < badges.length; i++) {
      Future.delayed(Duration(milliseconds: i * 500), () {
        if (context.mounted) {
          show(context, badges[i]);
        }
      });
    }
  }
}

class _BadgeNotificationWidget extends StatefulWidget {
  final Map<String, dynamic> badge;
  final VoidCallback onDismiss;

  const _BadgeNotificationWidget({
    required this.badge,
    required this.onDismiss,
  });

  @override
  State<_BadgeNotificationWidget> createState() => _BadgeNotificationWidgetState();
}

class _BadgeNotificationWidgetState extends State<_BadgeNotificationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    
    _controller.forward();
    
    // Auto dismiss after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _controller.reverse().then((_) => widget.onDismiss());
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'star': return Icons.star;
      case 'collections_bookmark': return Icons.collections_bookmark;
      case 'workspace_premium': return Icons.workspace_premium;
      case 'emoji_events': return Icons.emoji_events;
      case 'school': return Icons.school;
      case 'quiz': return Icons.quiz;
      case 'assignment_turned_in': return Icons.assignment_turned_in;
      case 'verified': return Icons.verified;
      case 'military_tech': return Icons.military_tech;
      case 'local_fire_department': return Icons.local_fire_department;
      case 'whatshot': return Icons.whatshot;
      case 'bolt': return Icons.bolt;
      case 'flash_on': return Icons.flash_on;
      case 'auto_awesome': return Icons.auto_awesome;
      case 'stars': return Icons.stars;
      case 'grade': return Icons.grade;
      case 'diamond': return Icons.diamond;
      case 'rocket_launch': return Icons.rocket_launch;
      case 'nightlight': return Icons.nightlight;
      case 'wb_sunny': return Icons.wb_sunny;
      case 'explore': return Icons.explore;
      case 'record_voice_over': return Icons.record_voice_over;
      case 'extension': return Icons.extension;
      case 'chat': return Icons.chat;
      default: return Icons.emoji_events;
    }
  }

  @override
  Widget build(BuildContext context) {
    final badgeColor = Color(widget.badge['color'] as int? ?? 0xFFFFD700);
    
    return SafeArea(
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _opacityAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Material(
                  color: Colors.transparent,
                  child: GestureDetector(
                    onTap: () {
                      _controller.reverse().then((_) => widget.onDismiss());
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            badgeColor.withValues(alpha: 0.9),
                            badgeColor.withValues(alpha: 0.7),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: badgeColor.withValues(alpha: 0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Badge icon with glow
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.3),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  blurRadius: 15,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Icon(
                              _getIconData(widget.badge['icon'] as String? ?? 'emoji_events'),
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Badge info
                          Flexible(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '🏆 Badge Unlocked!',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.badge['name'] as String? ?? 'Achievement',
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  widget.badge['description'] as String? ?? '',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.white.withValues(alpha: 0.8),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
