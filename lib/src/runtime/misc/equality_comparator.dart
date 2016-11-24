/**
 * This interface provides an abstract concept of object equality independent of
 * {@link Object#equals} (object equality) and the {@code ==} operator
 * (reference equality). It can be used to provide algorithm-specific unordered
 * comparisons without requiring changes to the object itself.
 *
 * @author Sam Harwell
 */
abstract class EqualityComparator<T> {
/**
 * This method returns a hash code for the specified object.
 *
 * @param obj The object.
 * @return The hash code for {@code obj}.
 */
  int getHashCode(T obj);

/**
 * This method tests if two objects are equal.
 *
 * @param a The first object to compare.
 * @param b The second object to compare.
 * @return {@code true} if {@code a} equals {@code b}, otherwise {@code false}.
 */
  bool equals(T a, T b);
}
