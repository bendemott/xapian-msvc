#include <xapian.h>

#include <cstdio>
#include <cstdlib>
#include <filesystem>
#include <iostream>
#include <string>

int main() {
  try {
    const auto db_path = (std::filesystem::temp_directory_path() / "xapian-cmake-smoke").string();
    std::filesystem::remove_all(db_path);

    Xapian::WritableDatabase db(db_path, Xapian::DB_CREATE_OR_OVERWRITE);
    Xapian::Document doc;
    doc.set_data("hello cmake");
    doc.add_term("hello");
    doc.add_term("cmake");
    db.add_document(doc);
    db.commit();

    Xapian::Database rdb(db_path);
    Xapian::Enquire enquire(rdb);
    enquire.set_query(Xapian::Query("cmake"));
    Xapian::MSet matches = enquire.get_mset(0, 10);
    if (matches.size() != 1) {
      std::cerr << "expected 1 hit, got " << matches.size() << "\n";
      return 1;
    }
    std::cout << "xapian-cmake-smoke ok: version=" << Xapian::version_string()
              << " hits=" << matches.size() << "\n";
    return 0;
  } catch (const Xapian::Error& e) {
    std::cerr << "Xapian::Error: " << e.get_msg() << "\n";
    return 2;
  }
}
