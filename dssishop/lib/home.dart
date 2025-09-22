import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'model.dart';
import 'page/product_list_page.dart';


class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final PageController _pageController = PageController(viewportFraction: 0.33);

  final List<String> topShop = [
    'Fashion',
    'Electronics',
    'Home',
    'Beauty',
    'Sports',
  ];
  
  // PocketBase config: adjust to your server if not localhost
  final String _pbBaseUrl = 'http://127.0.0.1:8090';
  final List<Product> _products = [];
  bool _loading = false;
  String? _error;

  final List<Map<String, String>> popularReviews = [
    {
      'user': 'Alice',
      'review': 'Great quality and fast delivery!',
      'product': 'Wireless Headphones',
    },
    {
      'user': 'Bob',
      'review': 'Amazing battery life on this watch.',
      'product': 'Smart Watch',
    },
    {
      'user': 'Carol',
      'review': 'Sound is crystal clear!',
      'product': 'Bluetooth Speaker',
    },
  ];

  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _unsubscribeRealtime();
    _pageController.dispose();
    super.dispose();
  }

  UnsubscribeFunc? _unsub;

  void _subscribeRealtime() {
    final pb = PocketBase(_pbBaseUrl);
    pb.collection('products').subscribe('*', (event) {
      if (!mounted) return;
      final rec = event.record;
      if (rec == null) return;
      final data = rec.data;
      final incoming = Product(
        name: data['name'] as String? ?? '',
        imgUrl: data['imgUrl'] as String? ?? '',
        price: (data['price'] is int) ? data['price'] as int : int.tryParse('${data['price']}') ?? 0,
      );

      setState(() {
        switch (event.action) {
          case 'create':
            _products.insert(0, incoming);
            break;
          case 'update':
            final idx = _products.indexWhere((x) => x.name == incoming.name && x.imgUrl == incoming.imgUrl);
            if (idx != -1) _products[idx] = incoming;
            break;
          case 'delete':
            // cannot identify by id since Product has no id; refresh instead
            _fetchProducts();
            break;
        }
      });
    }).then((fn) {
      _unsub = fn;
    }).catchError((_) {
      _unsub = null;
    });
  }

  void _unsubscribeRealtime() {
    try {
      _unsub?.call();
    } catch (_) {}
  }

  Future<void> _fetchProducts() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final pb = PocketBase(_pbBaseUrl);
      // Fetch first 30 products, newest first
      final res = await pb.collection('products').getList(page: 1, perPage: 30, sort: '-created');
      final items = res.items
          .map((r) => Product(
                name: r.data['name'] as String? ?? '',
                imgUrl: r.data['imgUrl'] as String? ?? '',
                price: (r.data['price'] is int)
                    ? r.data['price'] as int
                    : int.tryParse('${r.data['price']}') ?? 0,
              ))
          .where((p) => p.name.isNotEmpty && p.imgUrl.isNotEmpty)
          .toList();

      setState(() {
        _products
          ..clear()
          ..addAll(items);
        _currentPage = 0;
      });
    } catch (e) {
      setState(() => _error = 'Failed to load products: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _nextPage() {
    if (_pageController.hasClients && _currentPage < _products.length - 1) {
      _currentPage++;
      _pageController.animateToPage(
        _currentPage,
        duration: Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prevPage() {
    if (_pageController.hasClients && _currentPage > 0) {
      _currentPage--;
      _pageController.animateToPage(
        _currentPage,
        duration: Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  String _formatPrice(int value) {
    // format with thousand separators without adding intl dependency
    final digits = value.toString().split('').reversed.toList();
    final out = <String>[];
    for (var i = 0; i < digits.length; i++) {
      out.add(digits[i]);
      if ((i + 1) % 3 == 0 && i + 1 < digits.length) out.add(',');
    }
  return '\$${out.reversed.join()}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('DSSiShop'), centerTitle: true),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Shop Section
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Top Shops',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(
              height: 50,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: topShop.length,
                itemBuilder: (context, index) {
                  return Container(
                    margin: EdgeInsets.symmetric(horizontal: 8),
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(
                      child: Text(
                        topShop[index],
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Top Products Section with Slider
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Text(
                    'Top Products',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  Spacer(),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ProductListPage(
                            pbBaseUrl: _pbBaseUrl,
                            title: 'All Products',
                          ),
                        ),
                      );
                    },
                    child: const Text('See all'),
                  ),
                  IconButton(
                    icon: Icon(Icons.refresh),
                    tooltip: 'Reload',
                    onPressed: _fetchProducts,
                  ),
                  IconButton(
                    icon: Icon(Icons.arrow_back_ios),
                    onPressed: _prevPage,
                  ),
                  IconButton(
                    icon: Icon(Icons.arrow_forward_ios),
                    onPressed: _nextPage,
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 250,
              child: _loading
                  ? Center(child: CircularProgressIndicator())
                  : (_products.isEmpty)
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Text(
                              _error ?? 'No products found.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : PageView.builder(
                          controller: _pageController,
                          padEnds: false,
                          itemCount: _products.length,
                          onPageChanged: (index) {
                            setState(() {
                              _currentPage = index;
                            });
                          },
                          itemBuilder: (context, index) {
                            final product = _products[index];
                            return AnimatedContainer(
                              duration: Duration(milliseconds: 300),
                              margin: EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.shade300,
                                    blurRadius: 6,
                                    spreadRadius: 2,
                                    offset: Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(16),
                                      ),
                                      child: Image.network(
                                        product.imgUrl,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          color: Colors.grey.shade200,
                                          alignment: Alignment.center,
                                          child: Icon(Icons.broken_image, color: Colors.grey),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(6.0),
                                    child: Text(
                                      product.name,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 6.0),
                                    child: Text(
                                      _formatPrice(product.price),
                                      style: TextStyle(fontSize: 12, color: Colors.green),
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                ],
                              ),
                            );
                          },
                        ),
            ),

            // Popular Reviews Section
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Popular Reviews',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: popularReviews.length,
              itemBuilder: (context, index) {
                final review = popularReviews[index];
                return ListTile(
                  leading: CircleAvatar(child: Text(review['user']![0])),
                  title: Text(review['user']!),
                  subtitle: Text(
                    '"${review['review']!}"\nProduct: ${review['product']!}',
                  ),
                );
              },
            ),
            SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
