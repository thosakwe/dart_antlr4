/*
 * Copyright (c) 2012-2016 The ANTLR Project. All rights reserved.
 * Use of this file is governed by the BSD 3-clause license that
 * can be found in the LICENSE.txt file in the project root.
 */
import '../parser_rule_context.dart';
import 'error_node.dart';
import 'terminal_node.dart';

/** This interface describes the minimal core of methods triggered
 *  by {@link ParseTreeWalker}. E.g.,
 *
 *  	ParseTreeWalker walker = new ParseTreeWalker();
 *		walker.walk(myParseTreeListener, myParseTree); <-- triggers events in your listener
 *
 *  If you want to trigger events in multiple listeners during a single
 *  tree walk, you can use the ParseTreeDispatcher object available at
 *
 * 		https://github.com/antlr/antlr4/issues/841
 */
abstract class ParseTreeListener {
  void visitTerminal(TerminalNode node);
  void visitErrorNode(ErrorNode node);
  void enterEveryRule(ParserRuleContext ctx);
  void exitEveryRule(ParserRuleContext ctx);
}
