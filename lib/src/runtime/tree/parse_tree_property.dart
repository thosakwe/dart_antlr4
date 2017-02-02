/*
 * Copyright (c) 2012-2016 The ANTLR Project. All rights reserved.
 * Use of this file is governed by the BSD 3-clause license that
 * can be found in the LICENSE.txt file in the project root.
 */
import 'parse_tree.dart';

/**
 * Associate a property with a parse tree node. Useful with parse tree listeners
 * that need to associate values with particular tree nodes, kind of like
 * specifying a return value for the listener event method that visited a
 * particular node. Example:
 *
 * <pre>
 * ParseTreeProperty&lt;Integer&gt; values = new ParseTreeProperty&lt;Integer&gt;();
 * values.put(tree, 36);
 * int x = values.get(tree);
 * values.removeFrom(tree);
 * </pre>
 *
 * You would make one decl (values here) in the listener and use lots of times
 * in your event methods.
 */
class ParseTreeProperty<V> {
  Map<ParseTree, V> annotations = {};

  operator [](ParseTree node) => get(node);
  operator []=(ParseTree node, V value) => put(node, value);

  V get(ParseTree node) => annotations[node];
  void put(ParseTree node, V value) {
    annotations[node] = value;
  }

  V removeFrom(ParseTree node) => annotations.remove(node);
}
