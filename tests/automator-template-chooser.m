#import <Automator/AMTemplateChooserItem.h>
#include <stdio.h>
int main(void) {
 @autoreleasepool {
  NSArray *items=[AMTemplateChooserItem templateChooserItems];
  if ([items count] != 1) { fprintf(stderr,"FAIL expected a blank Workflow template, got %lu\n",(unsigned long)[items count]); return 1; }
  AMTemplateChooserItem *item=[[items objectAtIndex:0] retain];
  BOOL ok=[[item imageTitle] isEqualToString:@"Workflow"] && [[item templateDescription] length]>0;
  [item release];
  printf("%s Automator workflow chooser item\n",ok?"PASS":"FAIL"); return !ok;
 }
}
