/*
 * [The "BSD license"]
 *  Copyright (c) 2012 Terence Parr
 *  Copyright (c) 2012 Sam Harwell
 *  All rights reserved.
 *
 *  Redistribution and use in source and binary forms, with or without
 *  modification, are permitted provided that the following conditions
 *  are met:
 *
 *  1. Redistributions of source code must retain the above copyright
 *     notice, this list of conditions and the following disclaimer.
 *  2. Redistributions in binary form must reproduce the above copyright
 *     notice, this list of conditions and the following disclaimer in the
 *     documentation and/or other materials provided with the distribution.
 *  3. The name of the author may not be used to endorse or promote products
 *     derived from this software without specific prior written permission.
 *
 *  THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 *  IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 *  OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 *  IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 *  INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 *  NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 *  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 *  THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 *  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 *  THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import 'misc/utils.dart' as utils;
import 'console_error_listener.dart';
import 'error_listener.dart';
import 'int_stream.dart';
import 'recognition_exception.dart';
import 'rule_context.dart';
import 'token.dart';
import 'token_factory.dart';
import 'vocabulary.dart';
import 'vocabulary_impl.dart';

// abstract class Recognizer<Symbol, ATNInterpreter extends ATNSimulator>
abstract class Recognizer<Symbol, ATNSimulator> {
  static final int EOF = -1;

  static final Map<Vocabulary, Map<String, int>> _tokenTypeMapCache = {};
  static final Map<List<String>, Map<String, int>> _ruleIndexMapCache = {};

  List<ANTLRErrorListener> _listeners = [ConsoleErrorListener.INSTANCE];

  ATNInterpreter _interp;

  int _stateNumber = -1;

  /** Used to print out token names like ID during debugging and
	 *  error reporting.  The generated parsers implement a method
	 *  that overrides this to point to their String[] tokenNames.
	 *
	 * @deprecated Use {@link #this.vocabulary} instead.
	 */
  @deprecated
  List<String> get tokenNames;

  List<String> get ruleNames;

  /**
	 * Get the vocabulary used by the recognizer.
	 *
	 * @return A {@link Vocabulary} instance providing information about the
	 * vocabulary used by the grammar.
	 */
  Vocabulary get vocabulary {
    // ignore: DEPRECATED_MEMBER_USE
    return VocabularyImpl.fromTokenNames(tokenNames);
  }

  /**
	 * Get a map from token names to token types.
	 *
	 * <p>Used for XPath and tree pattern compilation.</p>
	 */
  Map<String, int> get tokenTypeMap {
    Vocabulary vocabulary = this.vocabulary;

    synchronized(tokenTypeMapCache) {
      Map<String, int> result = tokenTypeMapCache.get(vocabulary);

      if (result == null) {
        result = {};
        for (int i = 0; i < atn.maxTokenType; i++) {
          String literalName = vocabulary.getLiteralName(i);
          if (literalName != null) {
            result[literalName] = i;
          }

          String symbolicName = vocabulary.getSymbolicName(i);
          if (symbolicName != null) {
            result[symbolicName] = i;
          }
        }

        result["EOF"] = Token.EOF;
        result = new Map<String, int>.unmodifiable(result);
        tokenTypeMapCache.put(vocabulary, result);
      }

      return result;
    }

    return synchronized(_tokenTypeMapCache);
  }

  /**
	 * Get a map from rule names to rule indexes.
	 *
	 * <p>Used for XPath and tree pattern compilation.</p>
	 */
  Map<String, int> get ruleIndexMap {
    List<String> ruleNames = this.ruleNames;

    if (ruleNames == null) {
      throw new StateError(
          "The current recognizer does not provide a list of rule names.");
    }

    synchronized(ruleIndexMapCache) {
      Map<String, int> result = ruleIndexMapCache.get(ruleNames);
      if (result == null) {
        result = new Map.unmodifiable(utils.toMap(ruleNames));
        ruleIndexMapCache.put(ruleNames, result);
      }

      return result;
    }

    return synchronized(_ruleIndexMapCache);
  }

  int getTokenType(String tokenName) {
    int ttype = tokenTypeMap[tokenName];
    if (ttype != null) return ttype;
    return Token.INVALID_TYPE;
  }

  /**
	 * If this recognizer was generated, it will have a serialized ATN
	 * representation of the grammar.
	 *
	 * <p>For interpreters, we don't know their serialized ATN despite having
	 * created the interpreter from it.</p>
	 */
  String get serializedATN =>
      throw new StateError("there is no serialized ATN");

  /** For debugging and other purposes, might want the grammar name.
	 *  Have ANTLR generate an implementation for this method.
	 */
  String get grammarFileName;

  /**
	 * Get the {@link ATN} used by the recognizer for prediction.
	 *
	 * @return The {@link ATN} used by the recognizer for prediction.
	 */
  ATN get atn;

  /**
	 * Get the ATN interpreter used by the recognizer for prediction.
	 *
	 * @return The ATN interpreter used by the recognizer for prediction.
	 */
  ATNInterpreter get interpreter => _interp;

  /** If profiling during the parse/lex, this will return DecisionInfo records
	 *  for each decision in recognizer in a ParseInfo object.
	 *
	 * @since 4.3
	 */
  ParseInfo get parseInfo => null;

  /**
	 * Set the ATN interpreter used by the recognizer for prediction.
	 *
	 * @param interpreter The ATN interpreter used by the recognizer for
	 * prediction.
	 */
  void set interpreter(ATNInterpreter interpreter) {
    _interp = interpreter;
  }

  /** What is the error header, normally line/character position information? */
  String getErrorHeader(RecognitionException e) {
    int line = e.offendingToken.line;
    int charPositionInLine = e.offendingToken.charPositionInLine;
    return "line $line:$charPositionInLine";
  }

  /** How should a token be displayed in an error message? The default
	 *  is to display just the text, but during development you might
	 *  want to have a lot of information spit out.  Override in that case
	 *  to use t.toString() (which, for CommonToken, dumps everything about
	 *  the token). This is better than forcing you to override a method in
	 *  your token objects because you don't have to go modify your lexer
	 *  so that it creates a new Java type.
	 *
	 * @deprecated This method is not called by the ANTLR 4 Runtime. Specific
	 * implementations of {@link ANTLRErrorStrategy} may provide a similar
	 * feature when necessary. For example, see
	 * {@link DefaultErrorStrategy#getTokenErrorDisplay}.
	 */
  @deprecated
  String getTokenErrorDisplay(Token t) {
    if (t == null) return "<no token>";
    String s = t.text;

    if (s == null) {
      if (t.type == Token.EOF) {
        s = "<EOF>";
      } else {
        s = "<${t.type}>";
      }
    }

    s = s.replaceAll("\n", "\\n");
    s = s.replaceAll("\r", "\\r");
    s = s.replaceAll("\t", "\\t");
    return "'" + s + "'";
  }

  /**
	 * @exception NullPointerException if {@code listener} is {@code null}.
	 */
  void addErrorListener(ANTLRErrorListener listener) {
    if (listener == null) {
      throw new ArgumentError.notNull("listener");
    }

    _listeners.add(listener);
  }

  void removeErrorListener(ANTLRErrorListener listener) {
    _listeners.remove(listener);
  }

  void removeErrorListeners() => _listeners.clear();

  List<ANTLRErrorListener> get errorListeners => _listeners;

  ANTLRErrorListener get errorListenerDispatch =>
      new ProxyErrorListener(errorListeners);

  // subclass needs to override these if there are sempreds or actions
  // that the ATN interp needs to execute
  bool sempred(RuleContext _localctx, int ruleIndex, int actionIndex) => true;

  bool precpred(RuleContext localctx, int precedence) => true;

  void action(RuleContext _localctx, int ruleIndex, int actionIndex) {}

  int get state => _stateNumber;

  /** Indicate that the recognizer has changed internal state that is
	 *  consistent with the ATN state passed in.  This way we always know
	 *  where we are in the ATN as the parser goes along. The rule
	 *  context objects form a stack that lets us see the stack of
	 *  invoking rules. Combine this and we have complete ATN
	 *  configuration information.
	 */
  void set state(int atnState) {
    _stateNumber = atnState;
  }

  IntStream get inputStream;
  void set inputStream(IntStream input);

  TokenFactory get tokenFactory;
  void set tokenFactory(TokenFactory input);
}
