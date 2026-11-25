#include <stdlib.h>
void runApp(void);
void item(const char *title, int action);
void separator(void);
void beginSubmenu(const char *title);
void endSubmenu(void);
void notice(const char *title, const char *detail);
char *askText(const char *title, const char *initial);
char *askDate(const char *initial);
char *chooseFile(int saving, const char *initial);
int confirm(const char *title, const char *detail, const char *button);
int choose(const char *title, const char *detail, const char **options, int count);
void finishSearchOnMain(void);
