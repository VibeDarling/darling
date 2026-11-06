#include <xpc/xpc.h>
#include <xpc/connection.h>
#include <dispatch/dispatch.h>
#include <stdio.h>

#define SCREENSHOT_SERVICE "com.apple.systemuiserver.screencapture"

static void handle_request(xpc_connection_t peer, xpc_object_t request)
{
    if (xpc_get_type(request) != XPC_TYPE_DICTIONARY)
        return;

    // Screenshot.app sends { message: 1, nowait: true, args: ["-uUpi"] }.
    // Its asynchronous reply handler accepts an empty dictionary.  No screen
    // capture backend is available yet, so this only completes the XPC
    // handshake and must not be mistaken for an implemented capture command.
    if (xpc_dictionary_get_uint64(request, "message") != 1)
        return;

    xpc_object_t reply = xpc_dictionary_create_reply(request);
    if (reply) {
        xpc_connection_send_message(peer, reply);
        xpc_release(reply);
    }
    fprintf(stderr, "screenshotserviced: capture command is unsupported\n");
}

int main(void)
{
    xpc_connection_t listener = xpc_connection_create_mach_service(
        SCREENSHOT_SERVICE, NULL, XPC_CONNECTION_MACH_SERVICE_LISTENER);
    if (!listener)
        return 1;

    xpc_connection_set_event_handler(listener, ^(xpc_object_t event) {
        if (xpc_get_type(event) != XPC_TYPE_CONNECTION)
            return;

        xpc_connection_t peer = event;
        xpc_connection_set_event_handler(peer, ^(xpc_object_t request) {
            handle_request(peer, request);
        });
        xpc_connection_resume(peer);
    });
    xpc_connection_resume(listener);
    dispatch_main();
}
