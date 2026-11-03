#include <darling-boundary-diagnostics.h>

int main(int argc, char **argv) {
    const char *endpoint = getenv("DARLING_BOUNDARY_SOCKET");
    errno = ERANGE;
    darling_boundary_emit(endpoint, DARLING_DIAG_READY);
    if (argc > 1)
        darling_missing_import_emit(endpoint, argv[1]);
    return errno == ERANGE ? 0 : 71;
}
