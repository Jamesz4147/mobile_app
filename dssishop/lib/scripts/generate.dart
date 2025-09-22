import 'dart:async';
import 'dart:math';
import 'package:faker/faker.dart';
import 'package:pocketbase/pocketbase.dart';

Future<void> main() async {
  final pbUrl = 'http://127.0.0.1:8090'; // update if your PocketBase runs elsewhere
  final adminEmail = 'admin@ubu.ac.th';
  final adminPassword = '1234567890';

  final client = PocketBase(pbUrl);

  try {
    // authenticate as admin
    await client.admins.authWithPassword(adminEmail, adminPassword);
    print('Admin authenticated.');
  } catch (e) {
    print('Admin auth failed: $e');
    return;
  }

  final faker = Faker();
  final rnd = Random();

  Future<RecordModel> _createRecordFallback(Map<String, dynamic> body) async {
    // Only use the correct, recent PocketBase Dart API
    final coll = client.collection('products');
    final rec = await coll.create(body: body);
    return rec;
  }

  for (var i = 0; i < 100; i++) {
    final parts = faker.lorem.words(2);
    final name = '${_capitalize(parts[0])} ${_capitalize(parts[1])}';
    final imageId = 10 + rnd.nextInt(1000);
    final imgUrl = 'https://picsum.photos/id/$imageId/600/400';
    final price = 100 + rnd.nextInt(100000 - 100 + 1);

    final recordData = <String, dynamic>{
      'name': name,
      'imgUrl': imgUrl,
      'price': price, // <-- add numeric price field
    };

    try {
      final record = await _createRecordFallback(recordData);
      print('${i + 1}/100 created -> id: ${record.id} name: $name');
    } catch (e) {
      print('Failed to create record ${i + 1}: $e');
    }

    // small delay to avoid hammering PocketBase
    await Future.delayed(Duration(milliseconds: 150));
  }

  print('Done.');
}

String _capitalize(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';