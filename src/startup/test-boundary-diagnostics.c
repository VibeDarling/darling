#include <darling-boundary-diagnostics.h>

int main(int argc, char **argv) {
    const char *sample[] = {"DARLING_BOUNDARY_SOCKET_WRONG=/wrong", "DARLING_BOUNDARY_SOCKET=/correct", NULL};
    if (strcmp(darling_boundary_endpoint(sample), "/correct") != 0 || darling_boundary_endpoint(NULL))
        return 72;
    const char *endpoint = getenv("DARLING_BOUNDARY_SOCKET");
    errno = ERANGE;
    if (argc == 3 && strcmp(argv[1], "--event") == 0) {
        char *end;
        long event = strtol(argv[2], &end, 10);
        if (*end || event < 0 || event >= DARLING_DIAG_EVENT_COUNT)
            return 73;
        errno = ERANGE;
        darling_boundary_emit(endpoint, (enum darling_boundary_event)event);
        return errno == ERANGE ? 0 : 71;
    }
    darling_boundary_emit(endpoint, DARLING_DIAG_READY);
    if (argc > 1)
        darling_missing_import_emit(endpoint, argv[1]);
    return errno == ERANGE ? 0 : 71;
}
