/* SPDX-License-Identifier: GPL-2.0-or-later */
#include "magic_stub.h"

magic_t magic_open(int flags) {
  (void)flags;
  return (magic_t)0;
}

void magic_close(magic_t cookie) { (void)cookie; }

int magic_load(magic_t cookie, const char *magicfile) {
  (void)cookie;
  (void)magicfile;
  return -1;
}

const char *magic_file(magic_t cookie, const char *filename) {
  (void)cookie;
  (void)filename;
  return 0;
}

const char *magic_descriptor(magic_t cookie, int fd) {
  (void)cookie;
  (void)fd;
  return 0;
}

const char *magic_error(magic_t cookie) {
  (void)cookie;
  return "libmagic stub (no MIME database)";
}

int magic_errno(magic_t cookie) {
  (void)cookie;
  return 0;
}
