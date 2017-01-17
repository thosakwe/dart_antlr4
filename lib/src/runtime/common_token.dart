/*
 * Copyright (c) 2012-2016 The ANTLR Project. All rights reserved.
 * Use of this file is governed by the BSD 3-clause license that
 * can be found in the LICENSE.txt file in the project root.
 */
import 'misc/interval.dart';
import 'misc/pair.dart';
import 'char_stream.dart';
import 'recognizer.dart';
import 'token.dart';
import 'token_source.dart';
import 'writable_token.dart';

class CommonToken implements WritableToken, Serializable {
  /**
	 * An empty {@link Pair} which is used as the default value of
	 * {@link #source} for tokens that do not have a source.
	 */
  static final Pair<TokenSource, CharStream> EMPTY_SOURCE =
      new Pair<TokenSource, CharStream>(null, null);

  /**
	 * This is the backing field for {@link #getType} and {@link #setType}.
	 */
  int type;

  /**
	 * This is the backing field for {@link #getLine} and {@link #setLine}.
	 */
  int line;

  /**
	 * This is the backing field for {@link #getCharPositionInLine} and
	 * {@link #setCharPositionInLine}.
	 */
  int charPositionInLine = -1; // set to invalid position

  /**
	 * This is the backing field for {@link #getChannel} and
	 * {@link #setChannel}.
	 */
  int channel = Token.DEFAULT_CHANNEL;

  /**
	 * This is the backing field for {@link #getTokenSource} and
	 * {@link #getInputStream}.
	 *
	 * <p>
	 * These properties share a field to reduce the memory footprint of
	 * {@link CommonToken}. Tokens created by a {@link CommonTokenFactory} from
	 * the same source and input stream share a reference to the same
	 * {@link Pair} containing these values.</p>
	 */

  Pair<TokenSource, CharStream> source;

  /**
	 * This is the backing field for {@link #getText} when the token text is
	 * explicitly set in the constructor or via {@link #setText}.
	 *
	 * @see #getText()
	 */
  String _text;

  /**
	 * This is the backing field for {@link #getTokenIndex} and
	 * {@link #setTokenIndex}.
	 */
  int index = -1;

  /**
	 * This is the backing field for {@link #getStartIndex} and
	 * {@link #setStartIndex}.
	 */
  int start;

  /**
	 * This is the backing field for {@link #getStopIndex} and
	 * {@link #setStopIndex}.
	 */
  int stop;

  /**
	 * Constructs a new {@link CommonToken} with the specified token type.
	 *
	 * @param type The token type.
	 */
  CommonToken(int type, [String text]) {
    this.type = type;
    this.source = EMPTY_SOURCE;

    if (text != null) {
      this.channel = Token.DEFAULT_CHANNEL;
      _text = text;
    }
  }

  CommonToken.create(Pair<TokenSource, CharStream> source, int type,
      int channel, int start, int stop) {
    this.source = source;
    this.type = type;
    this.channel = channel;
    this.start = start;
    this.stop = stop;
    if (source.a != null) {
      this.line = source.a.line;
      this.charPositionInLine = source.a.charPositionInLine;
    }
  }

  /**
	 * Constructs a new {@link CommonToken} as a copy of another {@link Token}.
	 *
	 * <p>
	 * If {@code oldToken} is also a {@link CommonToken} instance, the newly
	 * constructed token will share a reference to the {@link #text} field and
	 * the {@link Pair} stored in {@link #source}. Otherwise, {@link #text} will
	 * be assigned the result of calling {@link #getText}, and {@link #source}
	 * will be constructed from the result of {@link Token#getTokenSource} and
	 * {@link Token#getInputStream}.</p>
	 *
	 * @param oldToken The token to copy.
	 */
  CommonToken.fromToken(Token oldToken) {
    type = oldToken.type;
    line = oldToken.line;
    index = oldToken.tokenIndex;
    charPositionInLine = oldToken.charPositionInLine;
    channel = oldToken.channel;
    start = oldToken.startIndex;
    stop = oldToken.stopIndex;

    if (oldToken is CommonToken) {
      _text = oldToken.text;
      source = oldToken.source;
    } else {
      _text = oldToken.text;
      source = new Pair<TokenSource, CharStream>(
          oldToken.tokenSource, oldToken.inputStream);
    }
  }

  @override
  String get text {
    if (_text != null) {
      return _text;
    }

    CharStream input = inputStream;
    if (input == null) return null;
    int n = input.size();
    if (start < n && stop < n) {
      return input.getText(Interval.of(start, stop));
    } else {
      return "<EOF>";
    }
  }

  /**
	 * Explicitly set the text for this token. If {code text} is not
	 * {@code null}, then {@link #getText} will return this value rather than
	 * extracting the text from the input.
	 *
	 * @param text The explicit text of the token, or {@code null} if the text
	 * should be obtained from the input along with the start and stop indexes
	 * of the token.
	 */
  @override
  void set text(String text) {
    _text = text;
  }

  @override
  TokenSource get tokenSource => source.a;

  @override
  CharStream get inputStream => source.b;

  @override
  String toString() => stringify();

  String stringify([Recognizer r]) {
    String channelStr = "";
    if (channel > 0) {
      channelStr = ",channel=$channel";
    }
    String txt = text;
    if (txt != null) {
      txt = txt.replaceAll("\n", "\\n");
      txt = txt.replaceAll("\r", "\\r");
      txt = txt.replaceAll("\t", "\\t");
    } else {
      txt = "<no text>";
    }
    String typeString = type?.toString();
    if (r != null) {
      typeString = r.vocabulary.getDisplayName(type);
    }

    return "[@$tokenIndex,$start:$stop='$txt',<$typeString>$channelStr,$line:$charPositionInLine]";
  }
}
