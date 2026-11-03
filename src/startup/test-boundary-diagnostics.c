#include <darling-boundary-diagnostics.h>

int main(int argc, char **argv) {
    const char *sample[] = {"DARLING_BOUNDARY_SOCKET_WRONG=/wrong", "DARLING_BOUNDARY_SOCKET=/correct", NULL};
    if (strcmp(darling_boundary_endpoint(sample), "/correct") != 0 || darling_boundary_endpoint(NULL))
        return 72;
    const char *endpoint = getenv("DARLING_BOUNDARY_SOCKET");
    errno = ERANGE;
    darling_boundary_emit(endpoint, DARLING_DIAG_READY);
    if (argc > 1)
        darling_missing_import_emit(endpoint, argv[1]);
    return errno == ERANGE ? 0 : 71;
}
