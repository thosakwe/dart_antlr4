/*
 * Copyright (c) 2012-2016 The ANTLR Project. All rights reserved.
 * Use of this file is governed by the BSD 3-clause license that
 * can be found in the LICENSE.txt file in the project root.
 */
import 'misc/interval.dart';
import 'misc/pair.dart';
import 'char_stream.dart';
import 'common_token.dart';
import 'token_factory.dart';
import 'token_source.dart';

/**
 * This default implementation of {@link TokenFactory} creates
 * {@link CommonToken} objects.
 */
class CommonTokenFactory implements TokenFactory<CommonToken> {
  /**
	 * The default {@link CommonTokenFactory} instance.
	 *
	 * <p>
	 * This token factory does not explicitly copy token text when constructing
	 * tokens.</p>
	 */
  static final TokenFactory<CommonToken> DEFAULT = new CommonTokenFactory(false);

  /**
	 * Indicates whether {@link CommonToken#setText} should be called after
	 * constructing tokens to explicitly set the text. This is useful for cases
	 * where the input stream might not be able to provide arbitrary substrings
	 * of text from the input after the lexer creates a token (e.g. the
	 * implementation of {@link CharStream#getText} in
	 * {@link UnbufferedCharStream} throws an
	 * {@link UnsupportedOperationException}). Explicitly setting the token text
	 * allows {@link Token#getText} to be called at any time regardless of the
	 * input stream implementation.
	 *
	 * <p>
	 * The default value is {@code false} to avoid the performance and memory
	 * overhead of copying text for every token unless explicitly requested.</p>
	 */
  final bool copyText;

  /**
	 * Constructs a {@link CommonTokenFactory} with the specified value for
	 * {@link #copyText}.
	 *
	 * <p>
	 * When {@code copyText} is {@code false}, the {@link #DEFAULT} instance
	 * should be used instead of constructing a new instance.</p>
	 *
	 * @param copyText The value for {@link #copyText}.
	 */
  CommonTokenFactory([this.copyText = false]);

  @override
  CommonToken create(
      Pair<TokenSource, CharStream> source,
      int type,
      String text,
      int channel,
      int start,
      int stop,
      int line,
      int charPositionInLine) {
    CommonToken t = new CommonToken.create(source, type, channel, start, stop);
    t
      ..line = line
      ..charPositionInLine = charPositionInLine;
    if (text != null) {
      t.text = text;
    } else if (copyText && source.b != null) {
      t.text = source.b.getText(Interval.of(start, stop));
    }

    return t;
  }

  @override
  CommonToken createToken(int type, String text) {
    return new CommonToken(type, text);
  }
}
