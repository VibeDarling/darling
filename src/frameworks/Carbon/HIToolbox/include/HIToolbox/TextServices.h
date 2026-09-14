#ifndef _Carbon_TextServices_H_
#define _Carbon_TextServices_H_

#ifdef __cplusplus
extern "C" {
#endif

typedef uint32_t TSMDocumentID;
typedef OSType InterfaceTypeList[1];

OSErr ActivateTSMDocument(TSMDocumentID a);
OSErr DeactivateTSMDocument(TSMDocumentID a);
OSErr NewTSMDocument(short a, InterfaceTypeList b, TSMDocumentID * c, long d);


OSErr UseInputWindow(TSMDocumentID a, Boolean b);

UInt32 TSMGetDeadKeyState(void);
void TSMSetDeadKeyState(UInt32 state);
OSStatus TSMProcessRawKeyCode(EventRef event);

#ifdef __cplusplus
}
#endif

#endif
