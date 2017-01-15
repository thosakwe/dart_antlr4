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
import 'dart:async';
import 'dart:math' as math;
import 'misc/interval.dart';
import 'char_stream.dart';
import 'int_stream.dart';

/**
 * Vacuum all input from a {@link Reader}/{@link InputStream} and then treat it
 * like a {@code char[]} buffer. Can also pass in a {@link String} or
 * {@code char[]} to use.
 *
 * <p>If you need encoding, pass in stream/reader with correct encoding.</p>
 */
class ANTLRInputStream implements CharStream, StreamConsumer<List<int>> {
  static final int READ_BUFFER_SIZE = 1024;
  static final int INITIAL_BUFFER_SIZE = 1024;

  bool _closed = false;

  /** The data being scanned */
  final List<int> data = [];

  /** How many characters are actually in the buffer */
  int get n => data.length;

  /** 0..n-1 index into string of next char */
  int p = 0;

  /** What is name or source of this char stream? */
  String name;

  ANTLRInputStream.empty() {}

  ANTLRInputStream.from(Iterable<int> data) {
    this.data.addAll(data ?? []);
  }

  factory ANTLRInputStream.fromString(String str) =>
      new ANTLRInputStream.from(str.codeUnits);

  static Future<ANTLRInputStream> fromStream(Stream<List<int>> stream) async {
    var input = new ANTLRInputStream.empty();
    await stream.pipe(input);
    return input;
  }

  @override
  Future addStream(Stream<List<int>> stream) async {
    if (_closed) throw new StateError('ANTLRInputStream is already closed.');

    var c = new Completer();

    stream.listen((buf) {
      this.data.addAll(buf);
    })
      ..onDone(c.complete)
      ..onError(c.completeError);

    return c.future;
  }

  @override
  Future close() async {
    _closed = true;
  }

  /** Reset the stream so that it's in the same state it was
	 *  when the object was created *except* the data array is not
	 *  touched.
	 */
  void reset() {
    p = 0;
  }

  @override
  void consume() {
    if (p >= n) {
      assert(LA(1) == IntStream.EOF);
      throw new StateError("cannot consume EOF");
    }

    //System.out.println("prev p="+p+", c="+(char)data[p]);
    if (p < n) {
      p++;
      //System.out.println("p moves to "+p+" (c='"+(char)data[p]+"')");
    }
  }

  @override
  int LA(int i) {
    if (i == 0) {
      return 0; // undefined
    }
    if (i < 0) {
      i++; // e.g., translate LA(-1) to use offset i=0; then data[p+0-1]
      if ((p + i - 1) < 0) {
        return IntStream.EOF; // invalid; no char before first char
      }
    }

    if ((p + i - 1) >= n) {
      //System.out.println("char LA("+i+")=EOF; p="+p);
      return IntStream.EOF;
    }
    //System.out.println("char LA("+i+")="+(char)data[p+i-1]+"; p="+p);
    //System.out.println("LA("+i+"); p="+p+" n="+n+" data.length="+data.length);
    return data[p + i - 1];
  }

  int LT(int i) {
    return LA(i);
  }

  /** Return the current input symbol index 0..n where n indicates the
     *  last symbol has been read.  The index is the index of char to
	 *  be returned from LA(1).
     */
  @override
  int index() {
    return p;
  }

  @override
  int size() {
    return n;
  }

  /** mark/release do nothing; we have entire buffer */
  @override
  int mark() {
    return -1;
  }

  @override
  void release(int marker) {}

  /** consume() ahead until p==index; can't just set p=index as we must
	 *  update line and charPositionInLine. If we seek backwards, just set p
	 */
  @override
  void seek(int index) {
    if (index <= p) {
      p = index; // just jump; don't update stream state (line, ...)
      return;
    }
    // seek forward, consume until p hits index or n (whichever comes first)
    index = math.min(index, n);
    while (p < index) {
      consume();
    }
  }

  @override
  String getText(Interval interval) {
    int start = interval.a;
    int stop = interval.b;
    if (stop >= n) stop = n - 1;
    int count = stop - start + 1;
    if (start >= n) return "";
//		System.err.println("data: "+Arrays.toString(data)+", n="+n+
//						   ", start="+start+
//						   ", stop="+stop);
    return data.skip(start).take(count).join();
  }

  @override
  String get sourceName {
    if (name == null || name.isEmpty) {
      return UNKNOWN_SOURCE_NAME;
    }

    return name;
  }

  @override
  String toString() => new String.fromCharCodes(data);
}

class Future {}
