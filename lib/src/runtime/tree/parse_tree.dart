import '../parser.dart';
import 'parse_tree_visitor.dart';
import 'syntax_tree.dart';

/** An interface to access the tree of {@link RuleContext} objects created
 *  during a parse that makes the data structure look like a simple parse tree.
 *  This node represents both internal nodes, rule invocations,
 *  and leaf nodes, token matches.
 *
 *  <p>The payload is either a {@link Token} or a {@link RuleContext} object.</p>
 */
abstract class ParseTree extends SyntaxTree {
	// the following methods narrow the return type; they are not additional methods
	@override
	ParseTree get parent;

	@override
	ParseTree getChild(int i);

	/** The {@link ParseTreeVisitor} needs a double dispatch method. */
  T accept<T>(ParseTreeVisitor<T> visitor);

	/** Return the combined text of all leaf nodes. Does not get any
	 *  off-channel tokens (if any) so won't return whitespace and
	 *  comments if they are sent to parser on hidden channel.
	 */
	String get text;

	/** Specialize toStringTree so that it can print out more information
	 * 	based upon the parser.
	 */
  @override
  String toStringTree([Parser parser]);
}