#include <CLucene.h>
#include "CLucene/search/Query.h"

#include <cstdio>
#include <memory>

int main() {
    try {
        lucene::store::RAMDirectory directory;
        lucene::analysis::standard::StandardAnalyzer analyzer;
        lucene::document::Document document;
        document.add(*_CLNEW lucene::document::Field(
            _T("content"), _T("faith hope charity"),
            lucene::document::Field::STORE_YES | lucene::document::Field::INDEX_TOKENIZED));

        lucene::index::IndexWriter writer(&directory, &analyzer, true);
        writer.addDocument(&document);
        writer.close();

        lucene::queryParser::QueryParser parser(_T("content"), &analyzer);
        std::unique_ptr<lucene::search::Query> query(parser.parse(_T("hope")));
        lucene::search::IndexSearcher searcher(&directory);
        std::unique_ptr<lucene::search::Hits> hits(searcher.search(query.get()));
        const bool matched = hits->length() == 1;
        hits.reset();
        searcher.close();
        if (!matched) {
            std::fputs("Expected exactly one indexed-search result.\n", stderr);
            return 1;
        }
    } catch (...) {
        std::fputs("CLucene indexing/search smoke test threw an exception.\n", stderr);
        return 1;
    }
    std::puts("CLucene indexing/search smoke test passed.");
    return 0;
}