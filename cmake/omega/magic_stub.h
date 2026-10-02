/* SPDX-License-Identifier: GPL-2.0-or-later */
/* Magic stub for platforms without libmagic (notably MSVC).
 * Extension-based MIME detection in omindex still works; magic returns empty.
 */
#ifndef XAPIAN_MSVC_MAGIC_STUB_H
#define XAPIAN_MSVC_MAGIC_STUB_H

#ifdef __cplusplus
extern "C" {
#endif

typedef struct magic_set *magic_t;

#ifndef MAGIC_NONE
# define MAGIC_NONE 0x0000000
#endif
#ifndef MAGIC_DEBUG
# define MAGIC_DEBUG 0x0000001
#endif
#ifndef MAGIC_SYMLINK
# define MAGIC_SYMLINK 0x0000002
#endif
#ifndef MAGIC_MIME
# define MAGIC_MIME 0x0000010
#endif
#ifndef MAGIC_MIME_TYPE
# define MAGIC_MIME_TYPE 0x0000400
#endif
#ifndef MAGIC_ERROR
# define MAGIC_ERROR 0x0000200
#endif
#ifndef MAGIC_VERSION
# define MAGIC_VERSION 540
#endif

magic_t magic_open(int flags);
void magic_close(magic_t cookie);
int magic_load(magic_t cookie, const char *magicfile);
const char *magic_file(magic_t cookie, const char *filename);
const char *magic_descriptor(magic_t cookie, int fd);
const char *magic_error(magic_t cookie);
int magic_errno(magic_t cookie);

#ifdef __cplusplus
}
#endif

#endif
