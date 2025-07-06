import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

import '../../core/app_export.dart';
import './widgets/category_chip_widget.dart';
import './widgets/listing_card_widget.dart';
import './widgets/location_selector_widget.dart';

class HomeMarketplaceFeed extends StatefulWidget {
  const HomeMarketplaceFeed({Key? key}) : super(key: key);

  @override
  State<HomeMarketplaceFeed> createState() => _HomeMarketplaceFeedState();
}

class _HomeMarketplaceFeedState extends State<HomeMarketplaceFeed>
    with TickerProviderStateMixin {
  late ScrollController _scrollController;
  bool _isLoading = false;
  bool _isRefreshing = false;
  bool _isLoadingCategories = false;
  int _currentIndex = 0;
  String _selectedCategory = 'All';
  String _selectedLocation = 'New York, NY';
  Set<String> _favoriteListings = {};

  // Real data from Supabase
  List<Map<String, dynamic>> _listings = [];
  List<Map<String, dynamic>> _categories = [];

  final CategoryService _categoryService = CategoryService();
  final ListingService _listingService = ListingService();
  final FavoriteService _favoriteService = FavoriteService();

  final List<String> _locations = [
    'New York, NY',
    'Los Angeles, CA',
    'Chicago, IL',
    'Houston, TX',
    'Phoenix, AZ',
    'Philadelphia, PA'
  ];

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _loadCategories(),
      _loadListings(),
      _loadFavorites(),
    ]);
  }

  Future<void> _loadCategories() async {
    try {
      setState(() {
        _isLoadingCategories = true;
      });

      final categories = await _categoryService.getMainCategories();

      setState(() {
        _categories = [
          {'id': 'all', 'name': 'All'},
          ...categories
              .map((cat) => {
                    'id': cat['id'],
                    'name': cat['name'],
                  })
              .toList(),
        ];
        _isLoadingCategories = false;
      });
    } catch (error) {
      setState(() {
        _isLoadingCategories = false;
        // Fallback to default categories if Supabase fails
        _categories = [
          {'id': 'all', 'name': 'All'},
          {'id': '1', 'name': 'Electronics'},
          {'id': '2', 'name': 'Furniture'},
          {'id': '3', 'name': 'Fashion'},
          {'id': '4', 'name': 'Sports'},
          {'id': '5', 'name': 'Automotive'},
          {'id': '6', 'name': 'Books'},
          {'id': '7', 'name': 'Home & Garden'},
        ];
      });
      debugPrint('❌ Failed to load categories: $error');
    }
  }

  Future<void> _loadListings() async {
    try {
      setState(() {
        _isLoading = true;
      });

      List<Map<String, dynamic>> listings;
      if (_selectedCategory == 'All') {
        listings = await _listingService.getActiveListings(limit: 20);
      } else {
        final categoryId = _categories.firstWhere(
            (cat) => cat['name'] == _selectedCategory,
            orElse: () => {'id': null})['id'];
        if (categoryId != null && categoryId != 'all') {
          listings = await _listingService.getListingsByCategory(categoryId,
              limit: 20);
        } else {
          listings = await _listingService.getActiveListings(limit: 20);
        }
      }

      setState(() {
        _listings = listings.map((listing) {
          final images = listing['images'] as List<dynamic>?;
          final firstImage = images?.isNotEmpty == true
              ? images!.first as String
              : 'https://images.unsplash.com/photo-1560472355-536de3962603?w=400&h=300&fit=crop';

          return {
            'id': listing['id'],
            'title': listing['title'],
            'price': '\$${listing['price']}',
            'location': listing['location'] ?? 'Unknown Location',
            'timePosted': _formatTimeAgo(DateTime.parse(listing['created_at'])),
            'imageUrl': firstImage,
            'category': listing['category']?['name'] ?? 'General',
            'isSponsored': listing['is_featured'] ?? false,
            'isFavorite': _favoriteListings.contains(listing['id']),
            'views_count': listing['views_count'] ?? 0,
            'condition': listing['condition'] ?? 'good',
            'seller': listing['seller'],
          };
        }).toList();
        _isLoading = false;
      });
    } catch (error) {
      setState(() {
        _isLoading = false;
        // Fallback to mock data if Supabase fails
        _listings = _getMockListings();
      });
      debugPrint('❌ Failed to load listings: $error');
    }
  }

  Future<void> _loadFavorites() async {
  try {
    final authService = AuthService();
    if (authService.isAuthenticated()) {
      final favorites = await _favoriteService.getUserFavorites();

      final Set<String> ids = favorites
          .map<String>((fav) => fav['listing_id'].toString())
          .toSet();

      setState(() {
        _favoriteListings = ids;
      });
    }
  } catch (error) {
    debugPrint('❌ Failed to load favorites: $error');
  }
}

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  List<Map<String, dynamic>> _getMockListings() {
    return [
      {
        "id": "1",
        "title": "iPhone 14 Pro Max - Excellent Condition",
        "price": "\$899",
        "location": "Manhattan, NY",
        "timePosted": "2 hours ago",
        "imageUrl":
            "https://images.unsplash.com/photo-1592750475338-74b7b21085ab?w=400&h=300&fit=crop",
        "category": "Electronics",
        "isSponsored": true,
        "isFavorite": false,
      },
      {
        "id": "2",
        "title": "MacBook Air M2 - Brand New Sealed",
        "price": "\$1199",
        "location": "Brooklyn, NY",
        "timePosted": "4 hours ago",
        "imageUrl":
            "https://images.unsplash.com/photo-1541807084-5c52b6b3adef?w=400&h=300&fit=crop",
        "category": "Electronics",
        "isSponsored": false,
        "isFavorite": false,
      },
      {
        "id": "3",
        "title": "Modern Dining Table Set",
        "price": "\$450",
        "location": "Queens, NY",
        "timePosted": "6 hours ago",
        "imageUrl":
            "https://images.unsplash.com/photo-1581539250439-c96689b516dd?w=400&h=300&fit=crop",
        "category": "Furniture",
        "isSponsored": false,
        "isFavorite": true,
      },
      {
        "id": "4",
        "title": "2020 Honda Civic - Low Mileage",
        "price": "\$18500",
        "location": "Bronx, NY",
        "timePosted": "1 day ago",
        "imageUrl":
            "https://images.unsplash.com/photo-1552519507-da3b142c6e3d?w=400&h=300&fit=crop",
        "category": "Automotive",
        "isSponsored": false,
        "isFavorite": false,
      },
    ];
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreListings();
    }
  }

  Future<void> _refreshListings() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    await Future.wait([
      _loadCategories(),
      _loadListings(),
      _loadFavorites(),
    ]);

    setState(() {
      _isRefreshing = false;
    });
  }

  Future<void> _loadMoreListings() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Load more listings with offset
      List<Map<String, dynamic>> moreListings;
      final offset = _listings.length;

      if (_selectedCategory == 'All') {
        moreListings =
            await _listingService.getActiveListings(limit: 10, offset: offset);
      } else {
        final categoryId = _categories.firstWhere(
            (cat) => cat['name'] == _selectedCategory,
            orElse: () => {'id': null})['id'];
        if (categoryId != null && categoryId != 'all') {
          moreListings = await _listingService.getListingsByCategory(categoryId,
              limit: 10);
        } else {
          moreListings = await _listingService.getActiveListings(
              limit: 10, offset: offset);
        }
      }

      setState(() {
        _listings.addAll(moreListings.map((listing) {
          final images = listing['images'] as List<dynamic>?;
          final firstImage = images?.isNotEmpty == true
              ? images!.first as String
              : 'https://images.unsplash.com/photo-1560472355-536de3962603?w=400&h=300&fit=crop';

          return {
            'id': listing['id'],
            'title': listing['title'],
            'price': '\$${listing['price']}',
            'location': listing['location'] ?? 'Unknown Location',
            'timePosted': _formatTimeAgo(DateTime.parse(listing['created_at'])),
            'imageUrl': firstImage,
            'category': listing['category']?['name'] ?? 'General',
            'isSponsored': listing['is_featured'] ?? false,
            'isFavorite': _favoriteListings.contains(listing['id'].toString()),
            'views_count': listing['views_count'] ?? 0,
            'condition': listing['condition'] ?? 'good',
            'seller': listing['seller'],
          };
        }));
        _isLoading = false;
      });
    } catch (error) {
      setState(() {
        _isLoading = false;
      });
      debugPrint('❌ Failed to load more listings: $error');
    }
  }

  Future<void> _toggleFavorite(String listingId) async {
    HapticFeedback.lightImpact();

    try {
      final authService = AuthService();
      if (!authService.isAuthenticated()) {
        // Navigate to login if not authenticated
        Navigator.pushNamed(context, AppRoutes.loginScreen);
        return;
      }

      if (_favoriteListings.contains(listingId)) {
        await _favoriteService.removeFavorite(listingId);
        setState(() {
          _favoriteListings.remove(listingId);
        });
      } else {
        await _favoriteService.addFavorite(listingId);
        setState(() {
          _favoriteListings.add(listingId);
        });
      }

      // Update the listing's favorite status in the list
      setState(() {
        final index =
            _listings.indexWhere((listing) => listing['id'] == listingId);
        if (index != -1) {
          _listings[index]['isFavorite'] =
              _favoriteListings.contains(listingId);
        }
      });
    } catch (error) {
      debugPrint('❌ Failed to toggle favorite: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update favorite'),
          backgroundColor: AppTheme.lightTheme.colorScheme.error,
        ),
      );
    }
  }

  void _onCategorySelected(String category) {
    setState(() {
      _selectedCategory = category;
    });
    _loadListings(); // Reload listings when category changes
  }

  void _onLocationChanged(String location) {
    setState(() {
      _selectedLocation = location;
    });
    // Could trigger location-based filtering here
    _loadListings();
  }

  void _onListingTap(Map<String, dynamic> listing) {
    Navigator.pushNamed(context, AppRoutes.listingDetail, arguments: listing);
  }

  void _onListingLongPress(Map<String, dynamic> listing) {
    HapticFeedback.mediumImpact();
    _showQuickActions(listing);
  }

  void _showQuickActions(Map<String, dynamic> listing) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppTheme.lightTheme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: AppTheme.lightTheme.colorScheme.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  ListTile(
                    leading: CustomIconWidget(
                      iconName: 'share',
                      color: AppTheme.lightTheme.colorScheme.primary,
                      size: 24,
                    ),
                    title: Text(
                      'Share',
                      style: AppTheme.lightTheme.textTheme.bodyLarge,
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      // Handle share
                    },
                  ),
                  ListTile(
                    leading: CustomIconWidget(
                      iconName: 'report',
                      color: AppTheme.lightTheme.colorScheme.error,
                      size: 24,
                    ),
                    title: Text(
                      'Report',
                      style: AppTheme.lightTheme.textTheme.bodyLarge,
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      // Handle report
                    },
                  ),
                  ListTile(
                    leading: CustomIconWidget(
                      iconName: 'visibility_off',
                      color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                      size: 24,
                    ),
                    title: Text(
                      'Hide similar',
                      style: AppTheme.lightTheme.textTheme.bodyLarge,
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      // Handle hide similar
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> get _filteredListings {
    if (_selectedCategory == 'All') {
      return _listings;
    }
    return _listings
        .where(
            (listing) => (listing['category'] as String) == _selectedCategory)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightTheme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Sticky Header
            Container(
              color: AppTheme.lightTheme.colorScheme.surface,
              padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
              child: Column(
                children: [
                  // Location and Notification Row
                  Row(
                    children: [
                      Expanded(
                        child: LocationSelectorWidget(
                          selectedLocation: _selectedLocation,
                          locations: _locations,
                          onLocationChanged: _onLocationChanged,
                        ),
                      ),
                      SizedBox(width: 3.w),
                      GestureDetector(
                        onTap: () {
                          // Handle notification tap
                        },
                        child: Container(
                          padding: EdgeInsets.all(2.w),
                          decoration: BoxDecoration(
                            color: AppTheme
                                .lightTheme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: CustomIconWidget(
                            iconName: 'notifications',
                            color: AppTheme.lightTheme.colorScheme.primary,
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 1.h),
                  // Category Chips
                  SizedBox(
                    height: 5.h,
                    child: _isLoadingCategories
                        ? Center(
                            child: CircularProgressIndicator(
                              color: AppTheme.lightTheme.colorScheme.primary,
                            ),
                          )
                        : ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _categories.length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: EdgeInsets.only(right: 2.w),
                                child: CategoryChipWidget(
                                  category: _categories[index]['name']!,
                                  isSelected: _selectedCategory ==
                                      _categories[index]['name'],
                                  onTap: () => _onCategorySelected(
                                      _categories[index]['name']!),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            // Main Content
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshListings,
                color: AppTheme.lightTheme.colorScheme.primary,
                child: _filteredListings.isEmpty && !_isLoading
                    ? _buildEmptyState()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: EdgeInsets.symmetric(
                            horizontal: 4.w, vertical: 1.h),
                        itemCount:
                            _filteredListings.length + (_isLoading ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _filteredListings.length) {
                            return _buildLoadingIndicator();
                          }

                          final listing = _filteredListings[index];
                          final isFavorite =
                              _favoriteListings.contains(listing['id']);

                          return Padding(
                            padding: EdgeInsets.only(bottom: 2.h),
                            child: ListingCardWidget(
                              listing: listing,
                              isFavorite: isFavorite,
                              onTap: () => _onListingTap(listing),
                              onLongPress: () => _onListingLongPress(listing),
                              onFavoriteTap: () =>
                                  _toggleFavorite(listing['id']),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppTheme.lightTheme.colorScheme.surface,
        selectedItemColor: AppTheme.lightTheme.colorScheme.primary,
        unselectedItemColor: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });

          switch (index) {
            case 0:
              // Already on Home
              break;
            case 1:
              Navigator.pushNamed(context, AppRoutes.searchAndFilters);
              break;
            case 2:
              Navigator.pushNamed(context, AppRoutes.createListing);
              break;
            case 3:
              Navigator.pushNamed(context, AppRoutes.chatMessaging);
              break;
            case 4:
              Navigator.pushNamed(context, AppRoutes.userProfile);
              break;
          }
        },
        items: [
          BottomNavigationBarItem(
            icon: CustomIconWidget(
              iconName: 'home',
              color: _currentIndex == 0
                  ? AppTheme.lightTheme.colorScheme.primary
                  : AppTheme.lightTheme.colorScheme.onSurfaceVariant,
              size: 24,
            ),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: CustomIconWidget(
              iconName: 'search',
              color: _currentIndex == 1
                  ? AppTheme.lightTheme.colorScheme.primary
                  : AppTheme.lightTheme.colorScheme.onSurfaceVariant,
              size: 24,
            ),
            label: 'Search',
          ),
          BottomNavigationBarItem(
            icon: CustomIconWidget(
              iconName: 'add_circle',
              color: _currentIndex == 2
                  ? AppTheme.lightTheme.colorScheme.primary
                  : AppTheme.lightTheme.colorScheme.onSurfaceVariant,
              size: 24,
            ),
            label: 'Sell',
          ),
          BottomNavigationBarItem(
            icon: CustomIconWidget(
              iconName: 'chat',
              color: _currentIndex == 3
                  ? AppTheme.lightTheme.colorScheme.primary
                  : AppTheme.lightTheme.colorScheme.onSurfaceVariant,
              size: 24,
            ),
            label: 'Messages',
          ),
          BottomNavigationBarItem(
            icon: CustomIconWidget(
              iconName: 'person',
              color: _currentIndex == 4
                  ? AppTheme.lightTheme.colorScheme.primary
                  : AppTheme.lightTheme.colorScheme.onSurfaceVariant,
              size: 24,
            ),
            label: 'Profile',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, AppRoutes.createListing);
        },
        backgroundColor: AppTheme.lightTheme.colorScheme.primary,
        child: CustomIconWidget(
          iconName: 'add',
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(8.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CustomIconWidget(
              iconName: 'search_off',
              color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
              size: 80,
            ),
            SizedBox(height: 3.h),
            Text(
              'No listings found',
              style: AppTheme.lightTheme.textTheme.headlineSmall?.copyWith(
                color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: 1.h),
            Text(
              'Try adjusting your location or category filters',
              style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 3.h),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _selectedCategory = 'All';
                });
                _loadListings();
              },
              child: const Text('Reset Filters'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      padding: EdgeInsets.all(4.w),
      child: Center(
        child: CircularProgressIndicator(
          color: AppTheme.lightTheme.colorScheme.primary,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
