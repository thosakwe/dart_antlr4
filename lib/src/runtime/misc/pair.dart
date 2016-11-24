import 'murmur_hash.dart';
import 'object_equality_comparator.dart';

class Pair<A, B> {
  final A a;
  final B b;

  Pair(this.a, this.b);

  @override
  bool operator ==(Object obj) {
    if (obj == this) {
      return true;
    } else if (!(obj is Pair)) {
      return false;
    }

    Pair other = obj;
    return ObjectEqualityComparator.INSTANCE.equals(a, other.a) &&
        ObjectEqualityComparator.INSTANCE.equals(b, other.b);
  }

  @override
  int get hashCode {
    int hash = MurmurHash.initialize();
    hash = MurmurHash.update(hash, a);
    hash = MurmurHash.update(hash, b);
    return MurmurHash.finish(hash, 2);
  }

  @override
  String toString() => "($a, $b)";
}
