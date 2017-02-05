/*
 * Copyright (c) 2012-2016 The ANTLR Project. All rights reserved.
 * Use of this file is governed by the BSD 3-clause license that
 * can be found in the LICENSE.txt file in the project root.
 */
import 'dart:collection';
import 'package:charcode/charcode.dart';
import 'misc/interval.dart';
import 'misc/pair.dart';
import 'char_stream.dart';
import 'common_token_factory.dart';
import 'error_listener.dart';
import 'int_stream.dart';
import 'recognition_exception.dart';
import 'recognizer.dart';
import 'token.dart';
import 'token_factory.dart';
import 'token_source.dart';

/** A lexer is recognizer that draws input symbols from a character stream.
 *  lexer grammars result in a subclass of this object. A Lexer object
 *  uses simplified match() and error recovery mechanisms in the interest
 *  of speed.
 */
abstract class Lexer extends Recognizer<int, LexerATNSimulator>
    implements TokenSource {
  static final int DEFAULT_MODE = 0;
  static final int MORE = -2;
  static final int SKIP = -3;

  static final int DEFAULT_TOKEN_CHANNEL = Token.DEFAULT_CHANNEL;
  static final int HIDDEN = Token.HIDDEN_CHANNEL;
  static final int MIN_CHAR_VALUE = '\u0000'.codeUnits.first;
  static final int MAX_CHAR_VALUE = '\uFFFE'.codeUnits.first;

  CharStream _input;
  Pair<TokenSource, CharStream> _tokenFactorySourcePair;

  /** How to create token objects */
  TokenFactory _factory = CommonTokenFactory.DEFAULT;

  /** The goal of all lexer rules/methods is to create a token object.
	 *  This is an instance variable as multiple rules may collaborate to
	 *  create a single token.  nextToken will return this object after
	 *  matching lexer rule(s).  If you subclass to allow multiple token
	 *  emissions, then set this to the last token to be matched or
	 *  something nonnull so that the auto token emit mechanism will not
	 *  emit another token.
	 */
  Token _token;

  /** What character index in the stream did the current token start at?
	 *  Needed, for example, to get the text for current token.  Set at
	 *  the start of nextToken.
	 */
  int _tokenStartCharIndex = -1;

  /** The line on which the first character of the token resides */
  int _tokenStartLine;

  /** The character position of first character within the line */
  int _tokenStartCharPositionInLine;

  /** Once we see EOF on char stream, next token will be EOF.
	 *  If you have DONE : EOF ; then you see DONE EOF.
	 */
  bool _hitEOF;

  /** The channel number for the current token */
  int _channel;

  /** The token type for the current token */
  int _type;

  final Queue<int> _modeStack = new Queue<int>();
  int _mode = Lexer.DEFAULT_MODE;

  /** You can set the text for the current token to override what is in
	 *  the input char buffer.  Use setText() or can set this instance var.
	 */
  String _text;

  Lexer([CharStream input]) {
    if (input != null) {
      this._input = input;
      this._tokenFactorySourcePair =
          new Pair<TokenSource, CharStream>(this, input);
    }
  }

  void reset() {
    // wack Lexer state variables
    if (_input != null) {
      _input.seek(0); // rewind the input
    }
    _token = null;
    _type = Token.INVALID_TYPE;
    _channel = Token.DEFAULT_CHANNEL;
    _tokenStartCharIndex = -1;
    _tokenStartCharPositionInLine = -1;
    _tokenStartLine = -1;
    _text = null;

    _hitEOF = false;
    _mode = Lexer.DEFAULT_MODE;
    _modeStack.clear();

    interpreter.reset();
  }

  /** Return a token from this source; i.e., match a token on the char
	 *  stream.
	 */
  @override
  Token nextToken() {
    if (_input == null) {
      throw new StateError("nextToken requires a non-null input stream.");
    }

    // Mark start location in char stream so unbuffered streams are
    // guaranteed at least have text of current token
    int tokenStartMarker = _input.mark();
    try {
      outer:
      while (true) {
        if (_hitEOF) {
          emitEOF();
          return _token;
        }

        _token = null;
        _channel = Token.DEFAULT_CHANNEL;
        _tokenStartCharIndex = _input.index();
        _tokenStartCharPositionInLine = interpreter.charPositionInLine;
        _tokenStartLine = interpreter.line;
        _text = null;
        do {
          _type = Token.INVALID_TYPE;
//				System.out.println("nextToken line "+tokenStartLine+" at "+((char)input.LA(1))+
//								   " in mode "+mode+
//								   " at index "+input.index());
          int ttype;
          try {
            ttype = interpreter.match(_input, _mode);
          } on LexerNoViableAltException catch (e) {
            notifyListeners(e); // report error
            recover(e);
            ttype = SKIP;
          }
          if (_input.LA(1) == IntStream.EOF) {
            _hitEOF = true;
          }
          if (_type == Token.INVALID_TYPE) _type = ttype;
          if (_type == SKIP) {
            continue outer;
          }
        } while (_type == MORE);
        if (_token == null) emit();
        return _token;
      }
    } finally {
      // make sure we release marker after match or
      // unbuffered char stream will keep buffering
      _input.release(tokenStartMarker);
    }
  }

  /** Instruct the lexer to skip creating a token for current lexer rule
	 *  and look for another token.  nextToken() knows to keep looking when
	 *  a lexer rule finishes with token set to SKIP_TOKEN.  Recall that
	 *  if token==null at end of any token rule, it creates one for you
	 *  and emits it.
	 */
  void skip() {
    _type = SKIP;
  }

  void more() {
    _type = MORE;
  }

  void mode(int m) {
    _mode = m;
  }

  void pushMode(int m) {
    if (LexerATNSimulator.debug) print("pushMode " + m.toString());
    _modeStack.addFirst(_mode);
    mode(m);
  }

  int popMode() {
    if (_modeStack.isEmpty) throw new StateError('Empty mode stack.');
    if (LexerATNSimulator.debug)
      print("popMode back to " + _modeStack.first.toString());
    mode(_modeStack.removeFirst());
    return _mode;
  }

  @override
  void set tokenFactory(TokenFactory factory) {
    this._factory = factory;
  }

  @override
  TokenFactory get tokenFactory {
    return _factory;
  }

  /** Set the char stream and reset the lexer */
  @override
  void set inputStream(IntStream input) {
    this._input = null;
    this._tokenFactorySourcePair =
        new Pair<TokenSource, CharStream>(this, _input);
    reset();
    this._input = input as CharStream;
    this._tokenFactorySourcePair =
        new Pair<TokenSource, CharStream>(this, _input);
  }

  @override
  String get sourceName => _input.sourceName;

  @override
  CharStream get inputStream => _input;

  /** By default does not support multiple emits per nextToken invocation
	 *  for efficiency reasons.  Subclass and override this method, nextToken,
	 *  and getToken (to push tokens into a list and pull from that list
	 *  rather than a single variable as this implementation does).
	 */
  emit([Token token]) {
    if (token != null) {
      //System.err.println("emit "+token);
      this._token = token;
    } else {
      Token t = _factory.create(
          _tokenFactorySourcePair,
          _type,
          _text,
          _channel,
          _tokenStartCharIndex,
          charIndex - 1,
          _tokenStartLine,
          _tokenStartCharPositionInLine);
      emit(t);
      return t;
    }
  }

  Token emitEOF() {
    int cpos = charPositionInLine;
    int line = this.line;
    Token eof = _factory.create(_tokenFactorySourcePair, Token.EOF, null,
        Token.DEFAULT_CHANNEL, _input.index(), _input.index() - 1, line, cpos);
    emit(eof);
    return eof;
  }

  @override
  int get line => interpreter.line;

  @override
  int get charPositionInLine => interpreter.charPositionInLine;

  void set line(int line) {
    interpreter.line = line;
  }

  void set charPositionInLine(int charPositionInLine) {
    interpreter.charPositionInLine = charPositionInLine;
  }

  /** What is the index of the current character of lookahead? */
  int get charIndex => _input.index();

  /** Return the text matched so far for the current token or any
	 *  text override.
	 */
  String get text {
    if (_text != null) {
      return _text;
    }
    return interpreter.getText(_input);
  }

  /** Set the complete text of this token; it wipes any previous
	 *  changes to the text.
	 */
  void set text(String text) {
    this._text = text;
  }

  /** Override if emitting multiple tokens. */
  Token get token => _token;

  void set token(Token _token) {
    this._token = _token;
  }

  void set type(int ttype) {
    _type = ttype;
  }

  int get type => _type;

  void set channel(int channel) {
    _channel = channel;
  }

  int get channel => _channel;

  List<String> get channelNames => null;

  List<String> get modeNames => null;

  /** Used to print out token names like ID during debugging and
	 *  error reporting.  The generated parsers implement a method
	 *  that overrides this to point to their String[] tokenNames.
	 */
  @override
  @deprecated
  List<String> get tokenNames => null;

  /** Return a list of all Token objects in input char stream.
	 *  Forces load of all tokens. Does not include EOF token.
	 */
  List<Token> getAllTokens() {
    List<Token> tokens = [];
    Token t = nextToken();
    while (t.type != Token.EOF) {
      tokens.add(t);
      t = nextToken();
    }
    return tokens;
  }

  void notifyListeners(LexerNoViableAltException e) {
    String text =
        _input.getText(Interval.of(_tokenStartCharIndex, _input.index()));
    String msg = "token recognition error at: '" + getErrorDisplay(text) + "'";

    ANTLRErrorListener listener = errorListenerDispatch;
    listener.syntaxError(
        this, null, _tokenStartLine, _tokenStartCharPositionInLine, msg, e);
  }

  String getErrorDisplay(String s) {
    var buf = new StringBuffer();
    for (int c in s.codeUnits) {
      buf.write(getErrorDisplay(new String.fromCharCode(c)));
    }
    return buf.toString();
  }

  String getCharErrorDisplay(int c) {
    String getErrorDisplay(int c) {
      String s = c.toString();

      switch (c) {
        case Token.EOF:
          s = "<EOF>";
          break;
        case $lf:
          s = "\\n";
          break;
        case $tab:
          s = "\\t";
          break;
        case $cr:
          s = "\\r";
          break;
      }
      return s;
    }

    String s = getErrorDisplay(c);
    return "'" + s + "'";
  }

  /** Lexers can normally match any char in it's vocabulary after matching
	 *  a token, so do the easy thing and just kill a character and hope
	 *  it all works out.  You can instead use the rule invocation stack
	 *  to do sophisticated error recovery if you are in a fragment rule.
	 */
  void recover(Exception re) {
    if (re is RecognitionException) {
      //System.out.println("consuming char "+(char)input.LA(1)+" during recovery");
      //re.printStackTrace();
      // TODO: Do we lose character or line position information?
      _input.consume();
    } else if (re is LexerNoViableAltException &&
        _input.LA(1) != IntStream.EOF) {
      // skip a char and try again
      interpreter.consume(_input);
    } else
      throw re;
  }
}
