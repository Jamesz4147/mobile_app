import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';

class ProductDeletePage extends StatefulWidget {
  const ProductDeletePage({
    super.key,
    this.pbBaseUrl = 'http://127.0.0.1:8090',
    this.perPage = 30,
    this.title = 'Delete Products',
  });

  final String pbBaseUrl;
  final int perPage;
  final String title;

  @override
  State<ProductDeletePage> createState() => _ProductDeletePageState();
}

class _ProductDeletePageState extends State<ProductDeletePage> {
  final List<_Item> _items = [];
  final ScrollController _scrollController = ScrollController();
  final Set<String> _deleting = {};
  bool _loading = false;
  bool _initialLoaded = false;
  int _page = 1;
  bool _hasMore = true;
  String? _error;
  UnsubscribeFunc? _unsub;

  @override
  void initState() {
    super.initState();
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
    final pb = PocketBase(widget.pbBaseUrl);
    pb.collection('products').subscribe('*', (event) {
      if (!mounted) return;
      final rec = event.record;
      if (rec == null) return;
      final data = rec.data;
      final incoming = _Item(
        id: rec.id,
        name: data['name'] as String? ?? '',
        imgUrl: data['imgUrl'] as String? ?? '',
        price: (data['price'] is int) ? data['price'] as int : int.tryParse('${data['price']}') ?? 0,
      );

      setState(() {
        switch (event.action) {
          case 'create':
            if (!_items.any((x) => x.id == incoming.id)) _items.insert(0, incoming);
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

  void _onScroll() {
    if (!_hasMore || _loading) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      _loadPage();
    }
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

  Future<void> _loadPage() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final pb = PocketBase(widget.pbBaseUrl);
      final pageRes = await pb
          .collection('products')
          .getList(page: _page, perPage: widget.perPage, sort: '-created');

      final newItems = pageRes.items.map((r) {
        final data = r.data;
        final name = (data['name'] as String?) ?? '';
        final imgUrl = (data['imgUrl'] as String?) ?? '';
        final priceRaw = data['price'];
        final price = priceRaw is int
            ? priceRaw
            : int.tryParse('$priceRaw') ?? 0;
        return _Item(id: r.id, name: name, imgUrl: imgUrl, price: price);
      }).toList();

      setState(() {
        _items.addAll(newItems);
        _page += 1;
        _hasMore = _page <= (pageRes.totalPages == 0 ? 1 : pageRes.totalPages);
        _initialLoaded = true;
      });
    } catch (e) {
      setState(() => _error = 'Failed to load products: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteItem(_Item item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete product?'),
        content: Text('Are you sure you want to delete\n"${item.name}" (id: ${item.id})?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _deleting.add(item.id));
    try {
      final pb = PocketBase(widget.pbBaseUrl);
      await pb.collection('products').delete(item.id);
      setState(() {
        _items.removeWhere((e) => e.id == item.id);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _deleting.remove(item.id));
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
          )
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
            child: Text(_error!, textAlign: TextAlign.center),
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

    return ListView.separated(
      controller: _scrollController,
      itemCount: _items.length + 1,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        if (index == _items.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: (_loading)
                  ? const CircularProgressIndicator()
                  : (!_hasMore)
                      ? const Text('No more products', style: TextStyle(color: Colors.grey))
                      : const SizedBox.shrink(),
            ),
          );
        }
        final item = _items[index];
        final deleting = _deleting.contains(item.id);
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.blue.shade50,
            child: Text(item.name.isNotEmpty ? item.name[0].toUpperCase() : '?'),
          ),
          title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text('id: ${item.id}\n${_formatPrice(item.price)}'),
          isThreeLine: true,
          trailing: deleting
              ? const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  tooltip: 'Delete',
                  onPressed: () => _deleteItem(item),
                ),
        );
      },
    );
  }
}

class _Item {
  final String id;
  final String name;
  final String imgUrl;
  final int price;
  _Item({required this.id, required this.name, required this.imgUrl, required this.price});
}
