/*
 * Copyright (c) 2012-2016 The ANTLR Project. All rights reserved.
 * Use of this file is governed by the BSD 3-clause license that
 * can be found in the LICENSE.txt file in the project root.
 */
import 'dart:collection';
import 'error_node.dart';
import 'parse_tree.dart';
import 'parse_tree_listener.dart';
import 'parse_tree_walker.dart';
import 'rule_node.dart';
import 'terminal_node.dart';

/**
 * An iterative (read: non-recursive) pre-order and post-order tree walker that
 * doesn't use the thread stack but heap-based stacks. Makes it possible to
 * process deeply nested parse trees.
 */
class IterativeParseTreeWalker extends ParseTreeWalker {
  @override
  void walk(ParseTreeListener listener, ParseTree t) {
    final Queue<ParseTree> nodeStack = new Queue<ParseTree>();
    final IntegerStack indexStack = new IntegerStack();

    ParseTree currentNode = t;
    int currentIndex = 0;

    while (currentNode != null) {
      // pre-order visit
      if (currentNode is ErrorNode) {
        listener.visitErrorNode(currentNode);
      } else if (currentNode is TerminalNode) {
        listener.visitTerminal(currentNode);
      } else {
        final RuleNode r = currentNode;
        enterRule(listener, r);
      }

      // Move down to first child, if exists
      if (currentNode.childCount > 0) {
        nodeStack.addFirst(currentNode);
        indexStack.push(currentIndex);
        currentIndex = 0;
        currentNode = currentNode.getChild(0);
        continue;
      }

      // No child nodes, so walk tree
      do {
        // post-order visit
        if (currentNode is RuleNode) {
          exitRule(listener, currentNode);
        }

        // No parent, so no siblings
        if (nodeStack.isEmpty) {
          currentNode = null;
          currentIndex = 0;
          break;
        }

        // Move to next sibling if possible
        currentNode = nodeStack.first.getChild(++currentIndex);
        if (currentNode != null) {
          break;
        }

        // No next, sibling, so move up
        currentNode = nodeStack.removeFirst();
        currentIndex = indexStack.pop();
      } while (currentNode != null);
    }
  }
}
