/*
 * Copyright (c) 2012-2016 The ANTLR Project. All rights reserved.
 * Use of this file is governed by the BSD 3-clause license that
 * can be found in the LICENSE.txt file in the project root.
 */
import '../vocabulary_impl.dart';
import 'dfa_class.dart';
import 'serializer.dart';

class LexerDFASerializer extends DFASerializer {
  LexerDFASerializer(DFA dfa) : super(dfa, VocabularyImpl.EMPTY_VOCABULARY);

  @override
  String getEdgeLabel(int i) => "'" + new String.fromCharCode(i) + "'";
}
