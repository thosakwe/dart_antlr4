/*
 * Copyright (c) 2012-2016 The ANTLR Project. All rights reserved.
 * Use of this file is governed by the BSD 3-clause license that
 * can be found in the LICENSE.txt file in the project root.
 */
import '../token.dart';
import 'error_node.dart';
import 'terminal_node_impl.dart';
import 'parse_tree_visitor.dart';

/** Represents a token that was consumed during resynchronization
 *  rather than during a valid match operation. For example,
 *  we will create this kind of a node during single token insertion
 *  and deletion as well as during "consume until error recovery set"
 *  upon no viable alternative exceptions.
 */
 class ErrorNodeImpl extends TerminalNodeImpl implements ErrorNode {
	 ErrorNodeImpl(Token token):super(token);

	@override
   T accept<T>(ParseTreeVisitor<T> visitor) {
		return visitor.visitErrorNode(this);
	}
}