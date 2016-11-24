class MurmurHash {
  static final int DEFAULT_SEED = 0;

  /**
   * Initialize the hash using the specified {@code seed}.
   *
   * @param seed the seed
   * @return the intermediate hash value
   */
  static int initialize([int seed]) {
    return seed ?? DEFAULT_SEED;
  }

  /**
   * Update the intermediate hash value for the next input {@code value}.
   *
   * @param hash the intermediate hash value
   * @param value the value to add to the current hash
   * @return the updated intermediate hash value
   */
  static int update(int hash, [value]) {
    final int c1 = 0xCC9E2D51;
    final int c2 = 0x1B873593;
    final int r1 = 15;
    final int r2 = 13;
    final int m = 5;
    final int n = 0xE6546B64;

    int k;

    if (value is int)
      k = value;
    else {
      k = value != null ? value.hashCode : 0;
    }

    k = k * c1;
    k = (k << r1) | (k >> (32 - r1));
    k = k * c2;

    hash = hash ^ k;
    hash = (hash << r2) | (hash >> (32 - r2));
    hash = hash * m + n;

    return hash;
  }

  /**
   * Apply the final computation steps to the intermediate value {@code hash}
   * to form the final result of the MurmurHash 3 hash function.
   *
   * @param hash the intermediate hash value
   * @param numberOfWords the number of integer values added to the hash
   * @return the final hash result
   */
  static int finish(int hash, int numberOfWords) {
    hash = hash ^ (numberOfWords * 4);
    hash = hash ^ (hash >> 16);
    hash = hash * 0x85EBCA6B;
    hash = hash ^ (hash >> 13);
    hash = hash * 0xC2B2AE35;
    hash = hash ^ (hash >> 16);
    return hash;
  }

  /**
   * Utility function to compute the hash code of an array using the
   * MurmurHash algorithm.
   *
   * @param <T> the array element type
   * @param data the array data
   * @param seed the seed for the MurmurHash algorithm
   * @return the hash code of the data
   */
  static int getHashCode(List data, int seed) {
    int hash = initialize(seed);

    for (final value in data) {
      hash = update(hash, value);
    }

    hash = finish(hash, data.length);
    return hash;
  }
}
