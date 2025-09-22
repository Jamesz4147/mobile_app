import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';

class ProductUpdatePage extends StatefulWidget {
  const ProductUpdatePage({
    super.key,
    required this.recordId,
    this.pbBaseUrl = 'http://127.0.0.1:8090',
    this.title = 'Update Product',
  });

  final String recordId;
  final String pbBaseUrl;
  final String title;

  @override
  State<ProductUpdatePage> createState() => _ProductUpdatePageState();
}

class _ProductUpdatePageState extends State<ProductUpdatePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _imgUrlCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _imgUrlCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final pb = PocketBase(widget.pbBaseUrl);
      final rec = await pb.collection('products').getOne(widget.recordId);
      final data = rec.data;
      _nameCtrl.text = (data['name'] as String?) ?? '';
      _imgUrlCtrl.text = (data['imgUrl'] as String?) ?? '';
      final priceRaw = data['price'];
      _priceCtrl.text = (priceRaw is int) ? priceRaw.toString() : (int.tryParse('$priceRaw')?.toString() ?? '0');
    } catch (e) {
      _error = 'Failed to load: $e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final pb = PocketBase(widget.pbBaseUrl);
      final body = <String, dynamic>{
        'name': _nameCtrl.text.trim(),
        'imgUrl': _imgUrlCtrl.text.trim(),
        'price': int.parse(_priceCtrl.text.trim()),
      };
      await pb.collection('products').update(widget.recordId, body: body);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved')));
        Navigator.of(context).maybePop(true);
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Save failed: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(_error!, style: const TextStyle(color: Colors.red)),
                      ),
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(labelText: 'Name'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _imgUrlCtrl,
                      decoration: const InputDecoration(labelText: 'Image URL'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _priceCtrl,
                      decoration: const InputDecoration(labelText: 'Price (int)'),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        final n = int.tryParse(v.trim());
                        if (n == null || n < 0) return 'Enter a valid number';
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 48,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.save),
                        label: const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
