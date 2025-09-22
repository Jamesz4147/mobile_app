import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
// Removed: '../model.dart' (not used directly after refactor)
import 'product_update_page.dart';
import 'product_delete_page.dart';

class ProductListPage extends StatefulWidget {
  const ProductListPage({
    super.key,
    this.pbBaseUrl = 'http://127.0.0.1:8090',
    this.perPage = 24,
    this.title = 'All Products',
  });

  final String pbBaseUrl;
  final int perPage;
  final String title;

  @override
  State<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends State<ProductListPage> {
  late final PocketBase _pb;
  final List<_PItem> _items = [];
  final ScrollController _scrollController = ScrollController();
  bool _loading = false;
  bool _initialLoaded = false;
  int _page = 1;
  bool _hasMore = true;
  String? _error;
  
  UnsubscribeFunc? _unsub;
  @override
  void initState() {
    super.initState();
    _pb = PocketBase(widget.pbBaseUrl);
    _loadPage();
    _scrollController.addListener(_onScroll);
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _unsubscribeRealtime();
    _scrollController.dispose();
    super.dispose();
  }

  void _subscribeRealtime() {
  _pb.collection('products').subscribe('*', (event) {
      if (!mounted) return;
      final rec = event.record;
      if (rec == null) return;
      final data = rec.data;
      final incoming = _PItem(
        id: rec.id,
        name: data['name'] as String? ?? '',
        imgUrl: data['imgUrl'] as String? ?? '',
        price: (data['price'] is int) ? data['price'] as int : int.tryParse('${data['price']}') ?? 0,
      );

      setState(() {
        switch (event.action) {
          case 'create':
            if (incoming.name.isNotEmpty && incoming.imgUrl.isNotEmpty) {
              if (!_items.any((x) => x.id == incoming.id)) {
                _items.insert(0, incoming);
              }
            }
            break;
          case 'update':
            final idx = _items.indexWhere((x) => x.id == incoming.id);
            if (idx != -1) _items[idx] = incoming;
            break;
          case 'delete':
            _items.removeWhere((x) => x.id == incoming.id);
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

  Future<void> _onRefresh() async {
    setState(() {
      _error = null;
      _page = 1;
      _hasMore = true;
    });
    _items.clear();
    await _loadPage();
  }

  void _onScroll() {
    if (!_hasMore || _loading) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      _loadPage();
    }
  }

  Future<void> _loadPage() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final pageRes = await _pb
          .collection('products')
          .getList(page: _page, perPage: widget.perPage, sort: '-created');

    final newItems = pageRes.items
      .map((r) {
      final name = r.data['name'] as String? ?? '';
      final imgUrl = r.data['imgUrl'] as String? ?? '';
      final price = (r.data['price'] is int)
        ? r.data['price'] as int
        : int.tryParse('${r.data['price']}') ?? 0;
      return _PItem(id: r.id, name: name, imgUrl: imgUrl, price: price);
      })
      .where((p) => p.name.isNotEmpty && p.imgUrl.isNotEmpty)
      .toList();

      setState(() {
        _items.addAll(newItems);
        _page += 1;
        _hasMore = _page <= (pageRes.totalPages == 0 ? 1 : pageRes.totalPages);
        _initialLoaded = true;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load products: $e';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatPrice(int value) {
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
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: 'Reload',
            icon: const Icon(Icons.refresh),
            onPressed: _onRefresh,
          ),
          IconButton(
            tooltip: 'Delete items',
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ProductDeletePage(pbBaseUrl: widget.pbBaseUrl),
                ),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (!_initialLoaded && _loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _items.isEmpty) {
      return ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }

    if (_items.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 120),
          Center(child: Text('No products found.')),
        ],
      );
    }

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(8),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.72,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final p = _items[index];
                return _ProductCard(
                  name: p.name,
                  imageUrl: p.imgUrl,
                  priceText: _formatPrice(p.price),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ProductUpdatePage(
                          recordId: p.id,
                          pbBaseUrl: widget.pbBaseUrl,
                        ),
                      ),
                    );
                  },
                );
              },
              childCount: _items.length,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: (_loading && _items.isNotEmpty)
                  ? const CircularProgressIndicator()
                  : (!_hasMore)
                      ? const Text(
                          'No more products',
                          style: TextStyle(color: Colors.grey),
                        )
                      : const SizedBox.shrink(),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.name,
    required this.imageUrl,
    required this.priceText,
    this.onTap,
  });

  final String name;
  final String imageUrl;
  final String priceText;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Image.network(
                  imageUrl,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.grey.shade200,
                    alignment: Alignment.center,
                    child: const Icon(Icons.broken_image, color: Colors.grey),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
              child: Text(
                priceText,
                style: const TextStyle(fontSize: 12, color: Colors.green),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PItem {
  final String id;
  final String name;
  final String imgUrl;
  final int price;
  _PItem({required this.id, required this.name, required this.imgUrl, required this.price});
}
