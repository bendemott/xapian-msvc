#include <xapian.h>
#include <xapian-letor.h>

#include <filesystem>
#include <iostream>
#include <string>
#include <vector>

int main() {
  try {
    const auto db_path =
        (std::filesystem::temp_directory_path() / "xapian-letor-smoke").string();
    std::filesystem::remove_all(db_path);

    Xapian::WritableDatabase wdb(db_path, Xapian::DB_CREATE_OR_OVERWRITE);
    Xapian::TermGenerator termgenerator;
    termgenerator.set_stemmer(Xapian::Stem("en"));

    {
      Xapian::Document doc;
      termgenerator.set_document(doc);
      termgenerator.index_text("Lions Tigers and Bears", 1, "S");
      termgenerator.index_text(
          "This paragraph talks about lions and tigers and bears.");
      wdb.add_document(doc);
    }
    {
      Xapian::Document doc;
      termgenerator.set_document(doc);
      termgenerator.index_text("Giraffes and Zebras", 1, "S");
      termgenerator.index_text(
          "Giraffes have long necks; zebras have stripes.");
      wdb.add_document(doc);
    }
    {
      Xapian::Document doc;
      termgenerator.set_document(doc);
      termgenerator.index_text("Tigers in the wild", 1, "S");
      termgenerator.index_text(
          "Tigers are massive beasts. A hungry tiger is scary.");
      wdb.add_document(doc);
    }
    wdb.commit();

    Xapian::Database db(db_path);
    Xapian::Enquire enquire(db);
    Xapian::Query query("tigers");
    enquire.set_query(query);
    Xapian::MSet mset = enquire.get_mset(0, 10);
    if (mset.empty()) {
      std::cerr << "expected hits for 'tigers'\n";
      return 1;
    }

    Xapian::FeatureList flist;
    std::vector<Xapian::FeatureVector> fvecs =
        flist.create_feature_vectors(mset, query, db);
    if (fvecs.empty()) {
      std::cerr << "FeatureList returned no feature vectors\n";
      return 1;
    }
    if (fvecs[0].get_fcount() <= 0) {
      std::cerr << "feature vector has no features\n";
      return 1;
    }

    std::cout << "xapian-letor-smoke ok: hits=" << mset.size()
              << " feature_vectors=" << fvecs.size()
              << " fcount=" << fvecs[0].get_fcount() << "\n";
    return 0;
  } catch (const Xapian::Error& e) {
    std::cerr << "Xapian::Error: " << e.get_type() << ": " << e.get_msg()
              << "\n";
    return 2;
  }
}
