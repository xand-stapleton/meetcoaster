#include <stdlib.h>
void runApp(void);
void item(const char *title, int action);
void separator(void);
void beginSubmenu(const char *title);
void endSubmenu(void);
void notice(const char *title, const char *detail);
char *askText(const char *title, const char *initial);
char *askDateTime(const char *initial, const char *source);
char *saveFile(const char *initial);
void loginItem(void);
int choose(const char *title, const char *detail, const char **options, int count);
void finishSearchOnMain(void);
void holidayItem(const char *name, const char *title, int warning);
void updateHolidayItems(const char *name, const char *next, const char *warning);
void finishHolidayLookup(void);
