import 'package:flutter/material.dart';
import 'package:vocaboost/services/avatar_service.dart';

/// Screen for customizing user avatar with unlockable items
class AvatarCustomizationScreen extends StatefulWidget {
  final bool isDarkMode;
  final Function(bool)? onToggleDarkMode;

  const AvatarCustomizationScreen({
    super.key,
    this.isDarkMode = false,
    this.onToggleDarkMode,
  });

  @override
  State<AvatarCustomizationScreen> createState() => _AvatarCustomizationScreenState();
}

class _AvatarCustomizationScreenState extends State<AvatarCustomizationScreen>
    with SingleTickerProviderStateMixin {
  final AvatarService _avatarService = AvatarService();
  
  late TabController _tabController;
  
  Map<String, String> _equippedItems = {};
  List<String> _unlockedItems = [];
  int _currentXP = 0;
  bool _isLoading = true;

  final List<Map<String, dynamic>> _categories = [
    {'id': AvatarService.categoryHead, 'name': 'Head', 'icon': Icons.face},
    {'id': AvatarService.categoryFace, 'name': 'Face', 'icon': Icons.visibility},
    {'id': AvatarService.categoryBody, 'name': 'Body', 'icon': Icons.person},
    {'id': AvatarService.categoryAccessory, 'name': 'Accessory', 'icon': Icons.star},
    {'id': AvatarService.categoryBackground, 'name': 'Background', 'icon': Icons.palette},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    _loadAvatarData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAvatarData() async {
    setState(() => _isLoading = true);
    
    try {
      final equipped = await _avatarService.getEquippedAvatar();
      final unlocked = await _avatarService.getUnlockedItems();
      final xp = await _avatarService.getCurrentXP();
      
      if (mounted) {
        setState(() {
          _equippedItems = equipped;
          _unlockedItems = unlocked;
          _currentXP = xp;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading avatar data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _unlockItem(Map<String, dynamic> item) async {
    final itemId = item['id'] as String;
    final xpCost = item['xpCost'] as int;

    // Confirm purchase
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Unlock ${item['name']}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              item['icon'] as String,
              style: const TextStyle(fontSize: 48),
            ),
            const SizedBox(height: 16),
            Text('Cost: $xpCost XP'),
            Text('Your XP: $_currentXP'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _currentXP >= xpCost ? () => Navigator.pop(context, true) : null,
            child: const Text('Unlock'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final result = await _avatarService.unlockItem(itemId);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] as String),
          backgroundColor: result['success'] == true ? Colors.green : Colors.red,
        ),
      );

      if (result['success'] == true) {
        _loadAvatarData();
      }
    }
  }

  Future<void> _equipItem(String category, String itemId) async {
    final success = await _avatarService.equipItem(category, itemId);
    
    if (mounted && success) {
      setState(() {
        _equippedItems[category] = itemId;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Item equipped!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🎨 Blue Hour Palette
    const kPrimary = Color(0xFF3B5FAE);
    const kLightBackground = Color(0xFFC7D4E8);
    const kDarkBackground = Color(0xFF071B34);
    const kDarkCard = Color(0xFF20304A);
    const kTextDark = Color(0xFF071B34);
    const kTextLight = Color(0xFFC7D4E8);

    final backgroundColor = widget.isDarkMode ? kDarkBackground : kLightBackground;
    final textColor = widget.isDarkMode ? kTextLight : kTextDark;
    final cardColor = widget.isDarkMode ? kDarkCard : Colors.white;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Customize Avatar', style: TextStyle(color: Colors.white)),
        backgroundColor: kPrimary,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.stars, color: Colors.amber, size: 20),
                const SizedBox(width: 4),
                Text(
                  '$_currentXP XP',
                  style: const TextStyle(
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: _categories.map((cat) => Tab(
            icon: Icon(cat['icon'] as IconData),
            text: cat['name'] as String,
          )).toList(),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: kPrimary))
          : Column(
              children: [
                // Avatar Preview
                Container(
                  padding: const EdgeInsets.all(24),
                  child: _buildAvatarPreview(cardColor, textColor),
                ),
                
                // Items Grid
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: _categories.map((cat) {
                      return _buildItemsGrid(
                        cat['id'] as String,
                        cardColor,
                        textColor,
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildAvatarPreview(Color cardColor, Color textColor) {
    // Get equipped item details
    final headItem = _avatarService.getItemById(_equippedItems[AvatarService.categoryHead] ?? 'head_default');
    final faceItem = _avatarService.getItemById(_equippedItems[AvatarService.categoryFace] ?? 'face_default');
    final accItem = _avatarService.getItemById(_equippedItems[AvatarService.categoryAccessory] ?? 'acc_none');
    final bgItem = _avatarService.getItemById(_equippedItems[AvatarService.categoryBackground] ?? 'bg_default');

    final bgColor = Color(bgItem?['color'] as int? ?? 0xFF3B5FAE);

    return Container(
      width: 160,
      height: 160,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: bgColor.withValues(alpha: 0.4),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Main face/head
          Text(
            headItem?['icon'] as String? ?? '😊',
            style: const TextStyle(fontSize: 80),
          ),
          // Accessory (positioned at bottom right)
          if (accItem != null && accItem['id'] != 'acc_none')
            Positioned(
              bottom: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Text(
                  accItem['icon'] as String,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            ),
          // Face accessory (positioned at top)
          if (faceItem != null && faceItem['id'] != 'face_default')
            Positioned(
              top: 35,
              child: Text(
                faceItem['icon'] as String,
                style: const TextStyle(fontSize: 32),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildItemsGrid(String category, Color cardColor, Color textColor) {
    final items = _avatarService.getItemsByCategory(category);
    
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.85,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final itemId = item['id'] as String;
        final isUnlocked = _unlockedItems.contains(itemId);
        final isEquipped = _equippedItems[category] == itemId;
        final xpCost = item['xpCost'] as int;
        final canAfford = _currentXP >= xpCost;

        return GestureDetector(
          onTap: () {
            if (isUnlocked) {
              _equipItem(category, itemId);
            } else {
              _unlockItem(item);
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: isEquipped
                  ? Border.all(color: Colors.green, width: 3)
                  : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Item content
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        item['icon'] as String,
                        style: TextStyle(
                          fontSize: 40,
                          color: isUnlocked ? null : Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item['name'] as String,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (!isUnlocked) ...[
                        const SizedBox(height: 2),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.stars,
                              size: 12,
                              color: canAfford ? Colors.amber : Colors.grey,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '$xpCost',
                              style: TextStyle(
                                fontSize: 10,
                                color: canAfford ? Colors.amber : Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                
                // Lock overlay
                if (!isUnlocked)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: Icon(Icons.lock, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                
                // Equipped badge
                if (isEquipped)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check, color: Colors.white, size: 12),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
