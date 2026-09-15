#include <CommonCrypto/CommonDigest.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static char* md_end(void* ctx, char* buf, size_t digest_len, int (*final_fn)(unsigned char*, void*))
{
	unsigned char digest[64];
	static const char hex[] = "0123456789abcdef";
	if (!buf)
	{
		buf = (char*)malloc(2 * digest_len + 1);
		if (!buf)
			return NULL;
	}
	final_fn(digest, ctx);
	for (size_t i = 0; i < digest_len; i++)
	{
		buf[i * 2] = hex[(digest[i] >> 4) & 0x0f];
		buf[i * 2 + 1] = hex[digest[i] & 0x0f];
	}
	buf[2 * digest_len] = '\0';
	return buf;
}

static char* md_fdchunk(int fd, char* buf, off_t ofs, off_t len,
                        size_t digest_len,
                        int (*init_fn)(void*),
                        int (*update_fn)(void*, const void*, CC_LONG),
                        int (*final_fn)(unsigned char*, void*),
                        void* ctx)
{
	if (len < 0)
	{
		errno = EINVAL;
		return NULL;
	}
	init_fn(ctx);
	if (ofs != 0)
	{
		errno = 0;
		if (lseek(fd, ofs, SEEK_SET) != ofs || (ofs == -1 && errno != 0))
		{
			return NULL;
		}
	}
	unsigned char buffer[16 * 1024];
	off_t remain = len;
	ssize_t readrv = 0;
	while (len == 0 || remain > 0)
	{
		size_t to_read = (len == 0 || remain > (off_t)sizeof(buffer)) ? sizeof(buffer) : (size_t)remain;
		readrv = read(fd, buffer, to_read);
		if (readrv <= 0)
			break;
		update_fn(ctx, buffer, (CC_LONG)readrv);
		if (len > 0)
			remain -= readrv;
	}
	if (readrv < 0)
		return NULL;
	return md_end(ctx, buf, digest_len, final_fn);
}

static char* md_filechunk(const char* filename, char* buf, off_t ofs, off_t len,
                          size_t digest_len,
                          int (*init_fn)(void*),
                          int (*update_fn)(void*, const void*, CC_LONG),
                          int (*final_fn)(unsigned char*, void*),
                          void* ctx)
{
	int fd = open(filename, O_RDONLY);
	if (fd < 0)
		return NULL;
	char* ret = md_fdchunk(fd, buf, ofs, len, digest_len, init_fn, update_fn, final_fn, ctx);
	int save_errno = errno;
	close(fd);
	errno = save_errno;
	return ret;
}

static char* md_data(const void* data, unsigned int len, char* buf,
                     size_t digest_len,
                     int (*init_fn)(void*),
                     int (*update_fn)(void*, const void*, CC_LONG),
                     int (*final_fn)(unsigned char*, void*),
                     void* ctx)
{
	init_fn(ctx);
	update_fn(ctx, data, (CC_LONG)len);
	return md_end(ctx, buf, digest_len, final_fn);
}

#define DEFINE_ALGO(name, cc_name, CTX_TYPE, DIGEST_LEN) \
	int name##Init(CTX_TYPE* c) { return cc_name##_Init(c); } \
	int name##Update(CTX_TYPE* c, const void* data, CC_LONG len) { return cc_name##_Update(c, data, len); } \
	int name##Final(unsigned char* md, CTX_TYPE* c) { return cc_name##_Final(md, c); } \
	unsigned char* name(const unsigned char* d, size_t n, unsigned char* md) { return cc_name(d, (CC_LONG)n, md); } \
	char* name##End(CTX_TYPE* c, char* buf) { \
		return md_end(c, buf, DIGEST_LEN, (int(*)(unsigned char*, void*))cc_name##_Final); \
	} \
	char* name##FdChunk(int fd, char* buf, off_t ofs, off_t len) { \
		CTX_TYPE ctx; \
		return md_fdchunk(fd, buf, ofs, len, DIGEST_LEN, \
		                  (int(*)(void*))cc_name##_Init, \
		                  (int(*)(void*, const void*, CC_LONG))cc_name##_Update, \
		                  (int(*)(unsigned char*, void*))cc_name##_Final, &ctx); \
	} \
	char* name##Fd(int fd, char* buf) { return name##FdChunk(fd, buf, 0, 0); } \
	char* name##FileChunk(const char* fn, char* buf, off_t ofs, off_t len) { \
		CTX_TYPE ctx; \
		return md_filechunk(fn, buf, ofs, len, DIGEST_LEN, \
		                    (int(*)(void*))cc_name##_Init, \
		                    (int(*)(void*, const void*, CC_LONG))cc_name##_Update, \
		                    (int(*)(unsigned char*, void*))cc_name##_Final, &ctx); \
	} \
	char* name##File(const char* fn, char* buf) { return name##FileChunk(fn, buf, 0, 0); } \
	char* name##Data(const void* data, unsigned int len, char* buf) { \
		CTX_TYPE ctx; \
		return md_data(data, len, buf, DIGEST_LEN, \
		               (int(*)(void*))cc_name##_Init, \
		               (int(*)(void*, const void*, CC_LONG))cc_name##_Update, \
		               (int(*)(unsigned char*, void*))cc_name##_Final, &ctx); \
	}

DEFINE_ALGO(MD2, CC_MD2, CC_MD2_CTX, CC_MD2_DIGEST_LENGTH)
DEFINE_ALGO(MD4, CC_MD4, CC_MD4_CTX, CC_MD4_DIGEST_LENGTH)
DEFINE_ALGO(MD5, CC_MD5, CC_MD5_CTX, CC_MD5_DIGEST_LENGTH)
DEFINE_ALGO(SHA1, CC_SHA1, CC_SHA1_CTX, CC_SHA1_DIGEST_LENGTH)
DEFINE_ALGO(SHA224, CC_SHA224, CC_SHA256_CTX, CC_SHA224_DIGEST_LENGTH)
DEFINE_ALGO(SHA256, CC_SHA256, CC_SHA256_CTX, CC_SHA256_DIGEST_LENGTH)
DEFINE_ALGO(SHA384, CC_SHA384, CC_SHA512_CTX, CC_SHA384_DIGEST_LENGTH)
DEFINE_ALGO(SHA512, CC_SHA512, CC_SHA512_CTX, CC_SHA512_DIGEST_LENGTH)

#define DEFINE_SHA_UNDERSCORE(prefix, base, CTX_TYPE) \
	int prefix##_Init(CTX_TYPE* c) { return base##Init(c); } \
	int prefix##_Update(CTX_TYPE* c, const void* data, CC_LONG len) { return base##Update(c, data, len); } \
	int prefix##_Final(unsigned char* md, CTX_TYPE* c) { return base##Final(md, c); } \
	char* prefix##_End(CTX_TYPE* c, char* buf) { return base##End(c, buf); } \
	char* prefix##_Fd(int fd, char* buf) { return base##Fd(fd, buf); } \
	char* prefix##_FdChunk(int fd, char* buf, off_t ofs, off_t len) { return base##FdChunk(fd, buf, ofs, len); } \
	char* prefix##_File(const char* fn, char* buf) { return base##File(fn, buf); } \
	char* prefix##_FileChunk(const char* fn, char* buf, off_t ofs, off_t len) { return base##FileChunk(fn, buf, ofs, len); } \
	char* prefix##_Data(const void* data, unsigned int len, char* buf) { return base##Data(data, len, buf); }

DEFINE_SHA_UNDERSCORE(SHA, SHA1, CC_SHA1_CTX)
DEFINE_SHA_UNDERSCORE(SHA1, SHA1, CC_SHA1_CTX)
DEFINE_SHA_UNDERSCORE(SHA224, SHA224, CC_SHA256_CTX)
DEFINE_SHA_UNDERSCORE(SHA256, SHA256, CC_SHA256_CTX)
DEFINE_SHA_UNDERSCORE(SHA384, SHA384, CC_SHA512_CTX)
DEFINE_SHA_UNDERSCORE(SHA512, SHA512, CC_SHA512_CTX)
