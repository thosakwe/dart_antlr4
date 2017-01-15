import 'parser_rule_context.dart';

/** A handy class for use with
 *
 *  options {contextSuperClass=org.antlr.v4.runtime.RuleContextWithAltNum;}
 *
 *  that provides a backing field / impl for the outer alternative number
 *  matched for an internal parse tree node.
 *
 *  I'm only putting into Java runtime as I'm certain I'm the only one that
 *  will really every use this.
 */
class RuleContextWithAltNum extends ParserRuleContext {
  int altNum;

  @override
  int get altNumber => altNum;
  @override
  void set altNumber(int altNum) {
    this.altNum = altNum;
  }

  RuleContextWithAltNum([ParserRuleContext parent, int invokingStateNumber])
      : super(parent, invokingStateNumber) {
    if (parent == null) altNum = ATN.INVALID_ALT_NUMBER;
  }
}
