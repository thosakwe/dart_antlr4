/*
 * Copyright (c) 2012-2016 The ANTLR Project. All rights reserved.
 * Use of this file is governed by the BSD 3-clause license that
 * can be found in the LICENSE.txt file in the project root.
 */
import '../misc/interval.dart';
import '../parser.dart';
import '../token.dart';
import 'parse_tree.dart';
import 'parse_tree_visitor.dart';
import 'terminal_node.dart';

class TerminalNodeImpl implements TerminalNode {
  @override
  Token symbol;

  @override
  ParseTree parent;

  TerminalNodeImpl(Token symbol) {
    this.symbol = symbol;
  }

  @override
  ParseTree getChild(int i) {
    return null;
  }

  @override
  Token get payload => symbol;

  @override
  Interval get sourceInterval {
    if (symbol == null) return Interval.INVALID;

    int tokenIndex = symbol.tokenIndex;
    return new Interval(tokenIndex, tokenIndex);
  }

  @override
  final int childCount = 0;

  @override
  T accept<T>(ParseTreeVisitor<T> visitor) {
    return visitor.visitTerminal(this);
  }

  @override
  String get text => symbol.text;

  @override
  String toStringTree([Parser parser]) => toString();

  @override
  String toString() {
    if (symbol.type == Token.EOF) return "<EOF>";
    return symbol.text;
  }
}
