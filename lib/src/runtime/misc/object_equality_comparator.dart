import 'abstract_equality_comparator.dart';

/**
 * This default implementation of {@link EqualityComparator} uses object equality
 * for comparisons by calling {@link Object#hashCode} and {@link Object#equals}.
 *
 * @author Sam Harwell
 */
class ObjectEqualityComparator extends AbstractEqualityComparator {
  static final ObjectEqualityComparator INSTANCE =
      new ObjectEqualityComparator();

/**
 * {@inheritDoc}
 *
 * <p>This implementation returns
 * {@code obj.}{@link Object#hashCode hashCode()}.</p>
 */
  @override
  int getHashCode(Object obj) {
    if (obj == null) {
      return 0;
    }

    return obj.hashCode;
  }

/**
 * {@inheritDoc}
 *
 * <p>This implementation relies on object equality. If both objects are
 * {@code null}, this method returns {@code true}. Otherwise if only
 * {@code a} is {@code null}, this method returns {@code false}. Otherwise,
 * this method returns the result of
 * {@code a.}{@link Object#equals equals}{@code (b)}.</p>
 */
  @override
  bool equals(Object a, Object b) {
    if (a == null) {
      return b == null;
    }

    return a == b;
  }
}
