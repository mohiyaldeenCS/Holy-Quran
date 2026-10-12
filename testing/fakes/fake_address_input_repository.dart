import 'package:holyquran/data/repositories/address_input_repository.dart';
import 'package:holyquran/utils/result.dart';

/// Answers name lookups from [names]; every lookup fails with [failure] when
/// it is set.
final class FakeAddressInputRepository implements AddressInputRepository {
  FakeAddressInputRepository({this.names = const {}, this.failure});

  final Map<String, int> names;
  Exception? failure;

  /// The names asked for, in order.
  final lookups = <String>[];

  @override
  Future<Result<int?>> surahNamed(String name) async {
    lookups.add(name);
    if (failure case final failure?) return Failure(failure);
    return Ok(names[name]);
  }
}
