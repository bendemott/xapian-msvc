#include <xapian.h>

#include <cmath>
#include <cstring>
#include <filesystem>
#include <iostream>
#include <string>
#include <vector>

namespace {

constexpr Xapian::valueno kVectorSlot = 0;

std::string pack_vector(const std::vector<float>& v) {
  return std::string(reinterpret_cast<const char*>(v.data()),
                     v.size() * sizeof(float));
}

std::vector<float> unpack_vector(std::string_view packed, std::size_t dims) {
  std::vector<float> out(dims, 0.f);
  const std::size_t nbytes = dims * sizeof(float);
  if (packed.size() >= nbytes) {
    std::memcpy(out.data(), packed.data(), nbytes);
  }
  return out;
}

double l2_norm(const std::vector<float>& v) {
  double s = 0.0;
  for (float x : v) s += double(x) * double(x);
  return std::sqrt(s);
}

double cosine(const std::vector<float>& a, const std::vector<float>& b) {
  if (a.size() != b.size() || a.empty()) return 0.0;
  double dot = 0.0;
  for (std::size_t i = 0; i < a.size(); ++i) {
    dot += double(a[i]) * double(b[i]);
  }
  const double na = l2_norm(a);
  const double nb = l2_norm(b);
  if (na == 0.0 || nb == 0.0) return 0.0;
  return dot / (na * nb);
}

/** Rank documents by cosine similarity of dense vectors stored in a value slot.
 *
 *  Xapian has no built-in ANN index; this smoke test shows the usual pattern of
 *  storing embeddings in values and scoring them via a PostingSource.
 */
class CosineVectorPostingSource : public Xapian::ValuePostingSource {
 public:
  CosineVectorPostingSource(Xapian::valueno slot, std::vector<float> query)
      : Xapian::ValuePostingSource(slot), query_(std::move(query)) {}

  double get_weight() const override {
    auto doc_vec = unpack_vector(get_value(), query_.size());
    // Map cosine [-1,1] -> [0,1] so weights stay non-negative.
    return 0.5 * (1.0 + cosine(query_, doc_vec));
  }

  void reset(const Xapian::Database& db,
             Xapian::doccount shard_index) override {
    Xapian::ValuePostingSource::reset(db, shard_index);
    set_maxweight(1.0);
  }

  CosineVectorPostingSource* clone() const override {
    return new CosineVectorPostingSource(get_slot(), query_);
  }

  std::string name() const override { return "CosineVectorPostingSource"; }

  std::string get_description() const override {
    return "CosineVectorPostingSource()";
  }

 private:
  std::vector<float> query_;
};

void add_doc(Xapian::WritableDatabase& db, const std::string& text,
             const std::vector<float>& embedding) {
  Xapian::Document doc;
  doc.set_data(text);
  doc.add_term("doc");  // common term so a boolean filter can match all
  doc.add_value(kVectorSlot, pack_vector(embedding));
  db.add_document(doc);
}

}  // namespace

int main() {
  try {
    const auto db_path =
        (std::filesystem::temp_directory_path() / "xapian-vector-smoke")
            .string();
    std::filesystem::remove_all(db_path);

    Xapian::WritableDatabase wdb(db_path, Xapian::DB_CREATE_OR_OVERWRITE);
    // 3-D toy embeddings: query is near "cat", far from "car".
    add_doc(wdb, "cat", {1.f, 0.f, 0.f});
    add_doc(wdb, "kitty", {0.9f, 0.1f, 0.f});
    add_doc(wdb, "car", {0.f, 1.f, 0.f});
    add_doc(wdb, "truck", {0.1f, 0.9f, 0.f});
    wdb.commit();

    Xapian::Database db(db_path);
    auto* source =
        new CosineVectorPostingSource(kVectorSlot, {1.f, 0.f, 0.f});
    Xapian::Query q(source->release());

    Xapian::Enquire enquire(db);
    enquire.set_query(q);
    Xapian::MSet mset = enquire.get_mset(0, 10);
    if (mset.size() != 4) {
      std::cerr << "expected 4 hits, got " << mset.size() << "\n";
      return 1;
    }

    const std::string top = mset[0].get_document().get_data();
    if (top != "cat" && top != "kitty") {
      std::cerr << "expected top hit cat/kitty, got '" << top << "'\n";
      return 1;
    }

    const std::string bottom = mset[mset.size() - 1].get_document().get_data();
    if (bottom != "car" && bottom != "truck") {
      std::cerr << "expected bottom hit car/truck, got '" << bottom << "'\n";
      return 1;
    }

    // Nearest neighbour of the query vector among stored docs should be "cat".
    if (mset[0].get_document().get_data() != "cat") {
      std::cerr << "expected exact nearest neighbour 'cat', got '"
                << mset[0].get_document().get_data() << "'\n";
      return 1;
    }

    std::cout << "xapian-vector-smoke ok: top=" << top
              << " weight=" << mset[0].get_weight() << "\n";
    return 0;
  } catch (const Xapian::Error& e) {
    std::cerr << "Xapian::Error: " << e.get_type() << ": " << e.get_msg()
              << "\n";
    return 2;
  }
}
